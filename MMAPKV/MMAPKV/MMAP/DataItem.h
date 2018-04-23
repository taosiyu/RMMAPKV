//
//  DataItem.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/8.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DATAITEM_STRUCT_SZIE 16

#ifdef __cplusplus

//每个字典中的元素都有一个数据体，表示后面key和value的大小
struct DataItem {
    size_t keySize;    //key的长度8B
    size_t valueSize;  //value的长度8B
    
};


#endif
