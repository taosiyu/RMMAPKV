//
//  SpeedCoder.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/9.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import <Foundation/Foundation.h>

//用于封装解封装
@interface SpeedCoder : NSObject

- (id)initForReadingWithData:(NSData *)data;

//封装成NSData
+(NSData*) encodeDataWithObject:(id)obj;

//解封装NSData -> NSDictionary
+(id) decodeFromData:(NSData*)oData;

@end
