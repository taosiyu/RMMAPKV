//
//  MMAPKV.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/3.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMAPKV : NSObject

+(instancetype)defaultMMAPKV;

+(instancetype)mmapkvWithID:(NSString*)mmapkvID;

//文件加密
+(void)tryResetFileProtection:(NSString*)path;

//文件是否存在
+ (BOOL) FileExist:(NSString*)nsFilePath;

//移除文件
+ (BOOL) RemoveFile:(NSString*)nsFilePath;

//set&get
-(BOOL)setInt32:(int32_t)value forKey:(NSString*)key;
-(int32_t)getInt32ForKey:(NSString*)key;
-(BOOL)setUInt32:(uint32_t)value forKey:(NSString*)key;
-(uint32_t)getUInt32ForKey:(NSString*)key;
-(BOOL)setInt64:(int64_t)value forKey:(NSString*)key;
-(int64_t)getInt64ForKey:(NSString*)key;
-(BOOL)setUInt64:(uint64_t)value forKey:(NSString*)key;
-(uint64_t)getUInt64ForKey:(NSString*)key;
-(BOOL)setBool:(bool)value forKey:(NSString*)key;
-(bool)getBoolForKey:(NSString*)key;
-(BOOL)setFloat:(float)value forKey:(NSString*)key;
-(float)getFloatForKey:(NSString*)key;
-(float)getFloatForKey:(NSString*)key defaultValue:(float)defaultValue;
-(BOOL)setDouble:(double)value forKey:(NSString*)key;
-(double)getDoubleForKey:(NSString*)key;
-(double)getDoubleForKey:(NSString*)key defaultValue:(double)defaultValue;
-(BOOL)setString:(NSString *)value forKey:(NSString*)key;
-(NSString *)getStringForKey:(NSString*)key;
-(NSString *)getStringForKey:(NSString*)key defaultValue:(NSString *)defaultValue;

@end
