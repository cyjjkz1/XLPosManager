//
//  XLSocketDefine.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/1.
//  Copyright © 2019年 ccd. All rights reserved.
//

#ifndef XLSocketDefine_h
#define XLSocketDefine_h



typedef NS_ENUM(NSInteger) {
    
    XLSocketConnectStatus_UnConnected       = 0<<0, // 未连接状态
    XLSocketConnectStatus_Connected         = 1<<0, // 连接状态
    XLSocketConnectStatus_DisconnectByUser  = 2<<0, // 主动断开连接
    XLSocketConnectStatus_Unknow            = 3<<0  // 未知
    
}XLSocketConnectStatus;


#endif /* XLSocketDefine_h */
