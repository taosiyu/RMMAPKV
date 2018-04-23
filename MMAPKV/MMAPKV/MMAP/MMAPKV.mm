//
//  MMAPKV.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/3.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "MMAPKV.h"
#import <UIKit/UIKit.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <unistd.h>
#import <zlib.h>
#import <algorithm>

#import "DataInput.h"
#import "DataOutput.h"
#import "MMAPUtility.h"

#import "DataItem.h"
#import "SpeedCoder.h"

class MMAPKVLock
{
    NSRecursiveLock* m_oLock; //递归锁
    
public:
    MMAPKVLock(NSRecursiveLock* oLock) : m_oLock(oLock)
    {
        [m_oLock lock];
    }
    ~MMAPKVLock()
    {
        [m_oLock unlock];
        m_oLock = nil;
    }
};

static NSRecursiveLock* MM_instanceLock;
static NSMutableDictionary* MM_instanceDic;
#define DEFAULT_MMAPKV_ID @"MMAPKV.default"

const int DEFAULT_MMAP_SIZE = getpagesize(); //系统扇页大小

@implementation MMAPKV{
    NSRecursiveLock* main_lock;
    NSMutableDictionary* m_dic;
    NSString* mm_mmapID;
    NSString* mm_path;
    NSString* mm_crcPath;
    
    DataOutput* m_output;
    
    size_t m_actualSize;
    
    BOOL mm_isInBackground;
    BOOL m_needLoadFromFile;
    
    int m_fd;
    char* m_ptr;
    size_t m_size;
    
    uint32_t m_crcDigest;
    int m_crcFd;
    char* m_crcPtr;
}

#pragma mark ###### init

+(void)initialize {
    if (self == MMAPKV.class) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            MM_instanceDic = [NSMutableDictionary dictionary];
            MM_instanceLock = [[NSRecursiveLock alloc] init];
        });
    }
}

+(instancetype)defaultMMAPKV {
    return [MMAPKV mmapkvWithID:DEFAULT_MMAPKV_ID];
}

+(instancetype)mmapkvWithID:(NSString*)mmapkvID {
    if (mmapkvID.length <= 0) {
        return nil;
    }
    MMAPKVLock lock(MM_instanceLock);
    
    MMAPKV* kv = [MM_instanceDic objectForKey:mmapkvID];
    if (kv == nil) {
        kv = [[MMAPKV alloc] initWithMMapkvID:mmapkvID];
        [MM_instanceDic setObject:kv forKey:mmapkvID];
    }
    return kv;
}

-(instancetype)initWithMMapkvID:(NSString*)mmapkvID {
    if (self = [super init]) {
        main_lock = [[NSRecursiveLock alloc] init];
        
        mm_mmapID = mmapkvID;
        
        mm_path = [MMAPKV mappedKVPathWithID:mm_mmapID];
        if(![MMAPKV FileExist:mm_path]) {
            [MMAPKV CreateFile:mm_path];
        }
        
        mm_crcPath = [mm_path stringByAppendingString:@".crc"];;
        
        [self loadFromFile];
        
        auto appState = [UIApplication sharedApplication].applicationState;
        if (appState != UIApplicationStateActive) {
            mm_isInBackground = YES;
        } else {
            mm_isInBackground = NO;
        }
        NSLog(@"m_isInBackground:%d, appState:%ld", mm_isInBackground, (long)appState);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

-(void)dealloc {
    MMAPKVLock lock(main_lock);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (m_ptr != MAP_FAILED && m_ptr != NULL) {
        munmap(m_ptr, m_size);
        m_ptr = NULL;
    }
    if (m_fd > 0) {
        close(m_fd);
        m_fd = -1;
    }
    if (m_output) {
        delete m_output;
        m_output = NULL;
    }
    
    if (m_crcPtr != NULL && m_crcPtr != MAP_FAILED) {
        munmap(m_crcPtr, computeFixed32Size(0));
        m_crcPtr = NULL;
    }
    if (m_crcFd > 0) {
        close(m_crcFd);
        m_crcFd = -1;
    }
}


#pragma mark ###### doc
+(NSString*)mappedKVPathWithID:(NSString*)mmapID
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* nsLibraryPath = (NSString*)[paths firstObject];
    if ([nsLibraryPath length] > 0) {
        return [nsLibraryPath stringByAppendingFormat:@"/mmapkv/%@", mmapID];
    } else {
        return @"";
    }
}

//这部份是用c语言的mmap开辟内存映射
-(void)loadFromFile {
    m_fd = open(mm_path.UTF8String, O_RDWR, S_IRWXU);
    //1.打开文件
    if (m_fd <= 0) {
        NSLog(@"fail to open:%@, %s", mm_path, strerror(errno));
    } else {
        m_size = 0;
        struct stat st = {};
        if (fstat(m_fd, &st) != -1) {
            m_size = (size_t)st.st_size;
            //2.获取文件大小
        }
        //3.和内存分页大小做比较
        if (m_size < DEFAULT_MMAP_SIZE || (m_size % DEFAULT_MMAP_SIZE != 0)) {
            //给最小页大小
            m_size = ((m_size / DEFAULT_MMAP_SIZE) + 1 ) * DEFAULT_MMAP_SIZE;
            if (ftruncate(m_fd, m_size) != 0) {
                m_size = (size_t)st.st_size;
            }
        }
        //m_size 一开始是4096Bit
        //4.开始开辟内存映射
        m_ptr = (char*)mmap(NULL, m_size, PROT_READ|PROT_WRITE, MAP_SHARED, m_fd, 0);
        if (m_ptr == MAP_FAILED) {
            NSLog(@"fail to mmap [%@], %s", mm_mmapID, strerror(errno));
        } else {
            const int offset = computeFixed32Size(0);
            
            NSData* lenBuffer = [NSData dataWithBytesNoCopy:m_ptr length:offset freeWhenDone:NO];
            //获取NSData对象
            @try {
                m_actualSize = DataInput(lenBuffer).readFixed32();//获取前4bit数据，代表数据总大小
            } @catch(NSException *exception) {
                NSLog(@"%@", exception);
            }
            NSLog(@"checkFileCRCValid = YES loading [%@] with %zu size in total, file size is %zu", mm_mmapID, m_actualSize, m_size);
            if (m_actualSize > 0) {
                if (m_actualSize < m_size && m_actualSize+offset <= m_size) {
                    if ([self checkFileCRCValid] == YES) {
                        //crc验证通过，取出所有的数据
                        NSData* inputBuffer = [NSData dataWithBytesNoCopy:m_ptr+offset length:m_actualSize freeWhenDone:NO];
                        //数据转换提取
                        m_dic = [SpeedCoder decodeFromData:inputBuffer];
                        m_output = new DataOutput(m_ptr+offset+m_actualSize, m_size-offset-m_actualSize);
                    } else {
                        //验证失效
                        [self writeAcutalSize:0];
                        m_output = new DataOutput(m_ptr+offset, m_size-offset);
                        [self recaculateCRCDigest];
                    }
                } else {
                    //数据超出m_size
                    NSLog(@"load [%@] error: %zu size in total, file size is %zu", mm_mmapID, m_actualSize, m_size);
                    [self writeAcutalSize:0];
                    m_output = new DataOutput(m_ptr+offset, m_size-offset);
                    [self recaculateCRCDigest];
                }
            } else {
                //第一次，初始化
                m_output = new DataOutput(m_ptr+offset, m_size-offset);
                [self recaculateCRCDigest];
            }
            NSLog(@"loaded [%@] with %zu values", mm_mmapID, (unsigned long)m_dic.count);
        }
    }
    if (m_dic == nil) {
        m_dic = [NSMutableDictionary dictionary];
    }
    
    if (![self isFileValid]) {
        NSLog(@"[%@] file not valid", mm_mmapID);
    }
    
    //沙盒加密
    [MMAPKV tryResetFileProtection:mm_path];
    [MMAPKV tryResetFileProtection:mm_crcPath];
    m_needLoadFromFile = NO;
}

#pragma mark ###### mmap

//查看现有存储大小够不够存储新数据
-(BOOL)isHasFreeMemorySize:(size_t)newSize {
    [self checkLoadData];
    
    if (![self isFileValid]) {
        NSLog(@"[%@] file not valid", mm_mmapID);
        return NO;
    }
    
    if (newSize >= m_output->freeSpace()) {
        //尝试重写
        static const int offset = computeFixed32Size(0);
        NSData* data = [SpeedCoder encodeDataWithObject:m_dic];
        size_t lenNeeded = data.length + offset + newSize;      //存储dic时需要的容量大小
        size_t futureUsage = newSize * std::max<size_t>(8, (m_dic.count+1)/2);
        
        if (lenNeeded >= m_size || (lenNeeded + futureUsage) >= m_size) {
            size_t oldSize = m_size;
            do {
                m_size *= 2;
            } while (lenNeeded + futureUsage >= m_size);
            NSLog(@"extending [%@] file size from %zu to %zu, incoming size:%zu, futrue usage:%zu",
                     mm_mmapID, oldSize, m_size, newSize, futureUsage);
            
            if (ftruncate(m_fd, m_size) != 0) {
                NSLog(@"fail to truncate [%@] to size %zu, %s", mm_mmapID, m_size, strerror(errno));
                m_size = oldSize;
                return NO;
            }
            
            if (munmap(m_ptr, oldSize) != 0) {
                NSLog(@"fail to munmap [%@], %s", mm_mmapID, strerror(errno));
            }
            m_ptr = (char*)mmap(m_ptr, m_size, PROT_READ|PROT_WRITE, MAP_SHARED, m_fd, 0);
            if (m_ptr == MAP_FAILED) {
                NSLog(@"fail to mmap [%@], %s", mm_mmapID, strerror(errno));
            }
            
            if (![self isFileValid]) {
                NSLog(@"[%@] file not valid", mm_mmapID);
                return NO;
            }
            delete m_output;
            m_output = new DataOutput(m_ptr+offset, m_size-offset);
            m_output->seek(m_actualSize);
        }
        
        if ([self writeAcutalSize:data.length] == NO) {
            return NO;
        }
        
        delete m_output;
        m_output = new DataOutput(m_ptr+offset, m_size-offset);
        BOOL ret = [self protectFromBackgroundWritting:m_actualSize writeBlock:^(DataOutput *output) {
            output->writeRawData(data);
        }];
        if (ret) {
            [self recaculateCRCDigest];
        }
        return ret;
    }
    return YES;
}

//crc32本地验证
-(BOOL)checkFileCRCValid {
    if (m_ptr != NULL && m_ptr != MAP_FAILED) {
        int offset = computeFixed32Size(0);
        m_crcDigest = (uint32_t)crc32(0, (const uint8_t*)m_ptr+offset, (uint32_t)m_actualSize);

        if ([MMAPKV FileExist:mm_crcPath] == NO) {
            NSLog(@"crc32 file not found:%@", mm_crcPath);
            return YES;
        }
        NSData* oData = [NSData dataWithContentsOfFile:mm_crcPath];
        uint32_t crc32 = 0;
        @try {
            DataInput input(oData);
            crc32 = input.readFixed32();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
        if (m_crcDigest == crc32) {
            //crc验证是0表示 大小正确
            return YES;
        }
        NSLog(@"check crc [%@] fail, crc32:%u, m_crcDigest:%u", mm_mmapID, crc32, m_crcDigest);
    }
    return NO;
}

-(void)recaculateCRCDigest {
    if (m_ptr != NULL && m_ptr != MAP_FAILED) {
        m_crcDigest = 0;
        int offset = computeFixed32Size(0);
        [self updateCRCDigest:(const uint8_t*)m_ptr+offset withSize:m_actualSize];
    }
}

//更新crc32验证
-(void)updateCRCDigest:(const uint8_t*)ptr withSize:(size_t)length {
    if (ptr == NULL) {
        return;
    }
    m_crcDigest = (uint32_t)crc32(m_crcDigest, ptr, (uint32_t)length);
    
    if (m_crcPtr == NULL || m_crcPtr == MAP_FAILED) {
        [self prepareCRCFile];
    }
    if (m_crcPtr == NULL || m_crcPtr == MAP_FAILED) {
        return;
    }
    
    static const size_t bufferLength = computeFixed32Size(0);
    if (mm_isInBackground) {
        if (mlock(m_crcPtr, bufferLength) != 0) {
            NSLog(@"fail to mlock crc [%@]-%p, %d:%s", mm_mmapID, m_crcPtr, errno, strerror(errno));
            return;
        }
    }
    
    @try {
        DataOutput output(m_crcPtr, bufferLength);
        output.writeFixed32((int32_t)m_crcDigest);
    } @catch(NSException *exception) {
        NSLog(@"%@", exception);
    }
    if (mm_isInBackground) {
        munlock(m_crcPtr, bufferLength);
    }
}

//准备crc沙盒文件
-(void)prepareCRCFile {
    if (m_crcPtr == NULL || m_crcPtr == MAP_FAILED) {
        if ([MMAPKV FileExist:mm_crcPath] == NO) {
            [MMAPKV CreateFile:mm_crcPath];
        }
        m_crcFd = open(mm_crcPath.UTF8String, O_RDWR, S_IRWXU);//打开文件
        if (m_crcFd <= 0) {
            NSLog(@"fail to open:%@, %s", mm_crcPath, strerror(errno));
            [MMAPKV RemoveFile:mm_crcPath];
        } else {
            size_t size = 0;
            struct stat st = {};
            if (fstat(m_crcFd, &st) != -1) {
                size = (size_t)st.st_size;
            }
            int fileLegth = DEFAULT_MMAP_SIZE;
            if (size < fileLegth) {
                size = fileLegth;
                if (ftruncate(m_crcFd, size) != 0) {
                    NSLog(@"fail to truncate [%@] to size %zu, %s", mm_crcPath, size, strerror(errno));
                    close(m_crcFd);
                    m_crcFd = -1;
                    [MMAPKV RemoveFile:mm_crcPath];
                    return;
                }
            }
            m_crcPtr = (char*)mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_SHARED, m_crcFd, 0);//crc文件校验映射
            if (m_crcPtr == MAP_FAILED) {
                NSLog(@"fail to mmap [%@], %s", mm_crcPath, strerror(errno));
                close(m_crcFd);
                m_crcFd = -1;
            }
        }
    }
}

+ (BOOL) RemoveFile:(NSString*)nsFilePath
{
    int ret = rmdir(nsFilePath.UTF8String);
    if (ret != 0) {
        NSLog(@"remove file failed. filePath=%@, err=%s", nsFilePath, strerror(errno));
        return NO;
    }
    return YES;
}

//tsytao 这个方法是在数据的头4bit位置写上
-(BOOL)writeAcutalSize:(size_t)actualSize {
    assert(m_ptr != 0);
    assert(m_ptr != MAP_FAILED);
    
    char* actualSizePtr = m_ptr;
    char* tmpPtr = NULL;
    static const int offset = computeFixed32Size(0);
    
    if (mm_isInBackground) {
        tmpPtr = m_ptr;
        if (mlock(tmpPtr, offset) != 0) {
            NSLog(@"fail to mmap [%@], %d:%s", mm_mmapID, errno, strerror(errno));
            return NO;
        } else {
            actualSizePtr = tmpPtr;
        }
    }
    
    @try {
        DataOutput output(actualSizePtr, offset);
        output.writeFixed32((int32_t)actualSize);
    } @catch(NSException *exception) {
        NSLog(@"%@", exception);
    }
    m_actualSize = actualSize;
    
    if (tmpPtr != NULL && tmpPtr != MAP_FAILED) {
        munlock(tmpPtr, offset);
    }
    return YES;
}

//判断信息数据完整性
-(BOOL)isFileValid {
    if (m_fd > 0 && m_size > 0 && m_output != NULL && m_ptr != NULL && m_ptr != MAP_FAILED) {
        return YES;
    }
    return NO;
}


#pragma mark ###### Set and Get
//数据按照二进制流写入文件

//int32
-(BOOL)setInt32:(int32_t)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeInt32Size(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeInt32(value);
    
    return [self setData:data forKey:key];
}
-(int32_t)getInt32ForKey:(NSString*)key {
    return [self getInt32ForKey:key defaultValue:0];
}
-(int32_t)getInt32ForKey:(NSString *)key defaultValue:(int32_t)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData*  data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getInt32();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//uint32
-(BOOL)setUInt32:(uint32_t)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeUInt32Size(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeUInt32(value);
    
    return [self setData:data forKey:key];
}
-(uint32_t)getUInt32ForKey:(NSString*)key {
    return [self getUInt32ForKey:key defaultValue:0];
}
-(uint32_t)getUInt32ForKey:(NSString *)key defaultValue:(uint32_t)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getUInt32();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//int64
-(BOOL)setInt64:(int64_t)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeInt64Size(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeInt64(value);
    
    return [self setData:data forKey:key];
}
-(int64_t)getInt64ForKey:(NSString*)key {
    return [self getInt64ForKey:key defaultValue:0];
}
-(int64_t)getInt64ForKey:(NSString *)key defaultValue:(int64_t)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getInt64();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//uint64
-(BOOL)setUInt64:(uint64_t)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeUInt64Size(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeUInt64(value);
    
    return [self setData:data forKey:key];
}
-(uint64_t)getUInt64ForKey:(NSString*)key {
    return [self getUInt64ForKey:key defaultValue:0];
}
-(uint64_t)getUInt64ForKey:(NSString *)key defaultValue:(uint64_t)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getUInt64();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//bool
-(BOOL)setBool:(bool)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeBoolSize(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeBool(value);
    
    return [self setData:data forKey:key];
}
-(bool)getBoolForKey:(NSString*)key {
    return [self getBoolForKey:key defaultValue:FALSE];
}
-(bool)getBoolForKey:(NSString *)key defaultValue:(bool)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getBool();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//float & double
-(BOOL)setFloat:(float)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeFloatSize(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeFloat(value);
    
    return [self setData:data forKey:key];
}
-(BOOL)setDouble:(double)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    size_t size = computeDoubleSize(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeDouble(value);
    
    return [self setData:data forKey:key];
}
-(float)getFloatForKey:(NSString*)key {
    return [self getFloatForKey:key defaultValue:0];
}
-(float)getFloatForKey:(NSString*)key defaultValue:(float)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getFloat();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

-(double)getDoubleForKey:(NSString*)key {
    return [self getDoubleForKey:key defaultValue:0];
}
-(double)getDoubleForKey:(NSString*)key defaultValue:(double)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getDouble();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}

//string
-(BOOL)setString:(NSString *)value forKey:(NSString*)key {
    if (key.length <= 0) {
        return FALSE;
    }
    uint64_t size = computeStringSize(value);
    NSMutableData* data = [NSMutableData dataWithLength:size];
    DataOutput output(data);
    output.writeStringValue(value, size);
    
    return [self setData:data forKey:key];
}
-(NSString *)getStringForKey:(NSString*)key {
    return [self getStringForKey:key defaultValue:@""];
}
-(NSString *)getStringForKey:(NSString*)key defaultValue:(NSString *)defaultValue {
    if (key.length <= 0) {
        return defaultValue;
    }
    NSData* data = [self getDataForKey:key];
    if (data.length > 0) {
        @try {
            DataInput input(data);
            return input.getString();
        } @catch(NSException *exception) {
            NSLog(@"%@", exception);
        }
    }
    return defaultValue;
}



//base get
-(NSData* )getDataForKey:(NSString*)key {
    MMAPKVLock lock(main_lock);
    [self checkLoadData];
    return [m_dic objectForKey:key];
}

-(void)checkLoadData {
    if (m_needLoadFromFile == NO) {
        return;
    }
    m_needLoadFromFile = NO;
    [self loadFromFile];
}

//二进制数据保存
-(BOOL)setData:(NSData*)data forKey:(NSString*)key {
    if (data.length <= 0 || key.length <= 0) {
        return NO;
    }
    
    //计算添加的数据所需要的大小
    size_t size = data.length + [key dataUsingEncoding:NSUTF8StringEncoding].length + DATAITEM_STRUCT_SZIE;
    
    MMAPKVLock lock(main_lock);
    
    BOOL hasEnoughSize = [self isHasFreeMemorySize:size];
    
    [m_dic setObject:data forKey:key];
    
    if (hasEnoughSize == NO || [self isFileValid] == NO) {
        return NO;
    }
    if (m_actualSize == 0) {
        NSData* allData = [SpeedCoder encodeDataWithObject:m_dic];
        if (allData.length > 0) {
            size_t dsize = allData.length;
            BOOL ret = [self writeAcutalSize:dsize];
            if (ret) {
                ret = [self protectFromBackgroundWritting:dsize writeBlock:^(DataOutput *output) {
                    output->writeRawData(allData);
                }];
                if (ret) {
                    [self recaculateCRCDigest];
                }
            }
            return ret;
        }
        return NO;
    } else {
        NSData* allData = [SpeedCoder encodeDataWithObject:@{key : data}];
        size_t dsize = allData.length;
        BOOL ret = [self writeAcutalSize:dsize];
        if (ret) {
            static const int offset = computeFixed32Size(0);
            ret = [self protectFromBackgroundWritting:dsize writeBlock:^(DataOutput *output) {
                output->writeData(allData);
            }];
            if (ret) {
                //这里是存储crc校验内容的
                [self updateCRCDigest:(const uint8_t*)m_ptr+offset+m_actualSize-dsize withSize:dsize];
            }
        }
        return ret;
    }
}

-(BOOL)protectFromBackgroundWritting:(size_t)size writeBlock:(void (^)(DataOutput* output))block {
    @try {
        if (mm_isInBackground) {
            static const int offset = computeFixed32Size(0);
            static const int pagesize = getpagesize();
            size_t realOffset = offset + m_actualSize - size;       //实际指针位置
            size_t pageOffset = (realOffset / pagesize) * pagesize; //一般为0
            size_t pointerOffset = realOffset - pageOffset;         //实际指针位置 - 扇区页面页数
            size_t mmapSize = offset + m_actualSize - pageOffset;
            char* ptr = m_ptr+pageOffset;
            if (mlock(ptr, mmapSize) != 0) {
                NSLog(@"fail to mlock [%@], %s", mm_mmapID, strerror(errno));
                return NO;
            } else {
                DataOutput output(ptr + pointerOffset, size);
                block(&output);
                m_output->seek(size);
            }
            munlock(ptr, mmapSize);
        } else {
            block(m_output);
        }
    } @catch(NSException *exception) {
        NSLog(@"%@", exception);
        return NO;
    }
    
    return YES;
}


#pragma mark ###### file

//文件是否存在
+ (BOOL) FileExist:(NSString*)nsFilePath
{
    if([nsFilePath length] == 0) {
        return NO;
    }
    
    struct stat temp;
    //lstat获取文件信息
    return lstat(nsFilePath.UTF8String, &temp) == 0;
}

//创建本地映射文件
+ (BOOL) CreateFile:(NSString*)nsFilePath
{
    NSFileManager* oFileMgr = [NSFileManager defaultManager];

    NSMutableDictionary* fileAttr = [NSMutableDictionary dictionary];
    [fileAttr setObject:NSFileProtectionCompleteUntilFirstUserAuthentication forKey:NSFileProtectionKey];
    if([oFileMgr createFileAtPath:nsFilePath contents:nil attributes:fileAttr]) {
        return YES;
    }

    NSString* nsPath = [nsFilePath stringByDeletingLastPathComponent];
    
    NSError* err;
    if([nsPath length] > 1 && ![oFileMgr createDirectoryAtPath:nsPath withIntermediateDirectories:YES attributes:nil error:&err]) {
        NSLog(@"create file path:%@ fail:%@", nsPath, [err localizedDescription]);
        return NO;
    }

    if(![oFileMgr createFileAtPath:nsFilePath contents:nil attributes:fileAttr]) {
        NSLog(@"create file path:%@ fail.", nsFilePath);
        return NO;
    }
    return YES;
}

//沙盒文件加密
+(void)tryResetFileProtection:(NSString*)path {
    @autoreleasepool {
        NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
        NSString* protection = [attr valueForKey:NSFileProtectionKey];
        NSLog(@"protection on [%@] is %@", path, protection);
        if ([protection isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication] == NO) {
            NSMutableDictionary* newAttr = [NSMutableDictionary dictionaryWithDictionary:attr];
            [newAttr setObject:NSFileProtectionCompleteUntilFirstUserAuthentication forKey:NSFileProtectionKey];
            NSError* err = nil;
            //            NSFileProtectionCompleteUntilFirstUserAuthentication：文件以加密形式存储在磁盘上，未开启机器时是不可以存取的，在用户第一次解锁设备之后（理解为开机后第一次解锁），你的app可以使用这个文件即使用户锁屏了也没关系。
            [[NSFileManager defaultManager] setAttributes:newAttr ofItemAtPath:path error:&err];
            if (err != nil) {
                NSLog(@"fail to set attribute %@ on [%@]: %@", NSFileProtectionCompleteUntilFirstUserAuthentication, path, err);
            }
        }
    }
}

#pragma mark ###### Application

-(void)onMemoryWarning {
    MMAPKVLock lock(main_lock);
    
    NSLog(@"cleaning on memory warning %@", mm_mmapID);
    
    m_needLoadFromFile = YES;
    
    [self clearMemoryState];
}

-(void)didEnterBackground {
    MMAPKVLock lock(main_lock);
    
    mm_isInBackground = YES;
    NSLog(@"mm_isInBackground:%d", mm_isInBackground);
}

-(void)didBecomeActive {
    MMAPKVLock lock(main_lock);
    
    mm_isInBackground = NO;
    NSLog(@"mm_isInBackground:%d", mm_isInBackground);
}

//清除
-(void)clearMemoryState {
    [m_dic removeAllObjects];
    
    if (m_output != NULL) {
        delete m_output;
    }
    
    m_output = NULL;
    
    if (m_ptr != NULL && m_ptr != MAP_FAILED) {
        if (munmap(m_ptr, m_size) != 0) {
            NSLog(@"fail to munmap [%@], %s", mm_mmapID, strerror(errno));
        }
    }
    m_ptr = NULL;
    
    if (m_fd > 0) {
        if (close(m_fd) != 0) {
            NSLog(@"fail to close [%@], %s", mm_mmapID, strerror(errno));
        }
    }
    m_fd = 0;
    m_size = 0;
    m_actualSize = 0;
}

@end
