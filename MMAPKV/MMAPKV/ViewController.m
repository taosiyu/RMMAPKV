//
//  ViewController.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/3.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "ViewController.h"
#import "MMAPKV.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CFTimeInterval begin = CFAbsoluteTimeGetCurrent();
    // Do any additional setup after loading the view, typically from a nib.
    MMAPKV* mmkv = [MMAPKV defaultMMAPKV];
    [mmkv setInt32:1024 forKey:@"int32"];
    [mmkv setInt32:1124 forKey:@"int33"];
    NSLog(@"int32:%d", [mmkv getInt32ForKey:@"int32"]);
    NSLog(@"int33:%d", [mmkv getInt32ForKey:@"int33"]);
    NSLog(@"=============> int32 ^^^^^^");
    [mmkv setBool:YES forKey:@"bool"];
    NSLog(@"bool:%d", [mmkv getBoolForKey:@"bool"]);
    NSLog(@"=============> bool ^^^^^^");
    [mmkv setInt64:999999999 forKey:@"int64"];
    NSLog(@"int64:%lli", [mmkv getInt64ForKey:@"int64"]);
    [mmkv setString:@"你看到了吗哈哈哈哈哈回家" forKey:@"string"];
    NSLog(@"string:%@", [mmkv getStringForKey:@"string"]);
    
    for (int i = 0; i< 100000; i++) {
         [mmkv setInt32:i forKey:[NSString stringWithFormat:@"intm%i",i]];
    }
    
    for (int i = 100000; i < 200000; i++) {
        [mmkv setString:[NSString stringWithFormat:@"%i",i] forKey:[NSString stringWithFormat:@"string%i",i]];
    }
    
    CFTimeInterval end = CFAbsoluteTimeGetCurrent();
    CFTimeInterval time = end - begin;
    NSLog(@"mmap花费时间为:%lf",time);
    
    //以下是NSUSerDefault
    NSUserDefaults *nsDefault = [NSUserDefaults standardUserDefaults];
    
    CFTimeInterval nsbegin = CFAbsoluteTimeGetCurrent();
    
    [nsDefault setInteger:1024 forKey:@"int32"];
    [nsDefault setInteger:1124 forKey:@"int33"];
    [nsDefault setBool:YES forKey:@"bool"];
    [nsDefault setInteger:999999999 forKey:@"int64"];
    [nsDefault setValue:@"你看到了吗哈哈哈哈哈回家" forKey:@"string"];
    for (int i = 0; i< 100000; i++) {
        [nsDefault setInteger:i forKey:[NSString stringWithFormat:@"intm%i",i]];
    }
    
    for (int i = 100000; i < 200000; i++) {
        [nsDefault setValue:[NSString stringWithFormat:@"%i",i] forKey:[NSString stringWithFormat:@"string%i",i]];
    }
    
    CFTimeInterval nsend = CFAbsoluteTimeGetCurrent();
    CFTimeInterval nstime = nsend - nsbegin;
    NSLog(@"NSUserDefaults花费时间为:%lf",nstime);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
