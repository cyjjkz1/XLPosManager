//
//  XLError.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/3.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLError.h"
#import "XLConfigManager.h"
void XLLog(NSString *format, ...)
{
    if ([[[XLConfigManager share] getDebugModel] isEqualToString:@"1"]) {
        va_list args;
        va_start(args, format);
        NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        printf("\n-------------DEBUG---------------\n");
        printf("%s\n", [str UTF8String]);
        printf("\n---------------------------------\n");
    }else{
        //不输出调试日志
    }
}
@implementation XLError

@end
