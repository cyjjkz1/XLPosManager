//
//  XLSocketHandler.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/1.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLSocketHandler.h"
#import "GCDAsyncSocket.h"
//#import "NSString+Transform.h"
#import "TransformNSString.h"
#import "XLError.h"
#import "XLISO8583Handler.h"
#import "XLConfig.h"
#import "XLConfigManager.h"
@interface XLSocketHandler ()<GCDAsyncSocketDelegate>
// 迅联通信socket
@property (nonatomic, strong) GCDAsyncSocket *xlCommunicateSocket;
//
@property (nonatomic, strong) NSMutableArray *delegates;

@property (nonatomic, assign) NSUInteger autoConnectCount;

@end


@implementation XLSocketHandler

#pragma mark - 初始化通信socket实例
+ (instancetype)shareInstance
{
    static XLSocketHandler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[XLSocketHandler alloc] init];
    });
    return handler;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        //将handler设置成接收TCP信息的代理
        _xlCommunicateSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        //设置默认关闭读取
        [_xlCommunicateSocket setAutoDisconnectOnClosedReadStream:NO];
        //默认状态未连接
        _connectStatus = XLSocketConnectStatus_UnConnected;
        
        _autoConnectCount = 5;
    };
    return self;
}
#pragma mark - 连接服务器端口
- (void)connectServerHostWithSuccessBlock:(HandleResultBlock) successCB
                              failedBlock:(HandleResultBlock) failedCB
{
    NSError *error = nil;
    [_xlCommunicateSocket connectToHost:[[XLConfigManager share] getHost] onPort:[[XLConfigManager share] getPort] error:&error];
    if (error) {
        XLLog(@"----------------连接服务器失败----------------");
        if (failedCB) {
            failedCB([XLResponseModel createRespMsgWithCode:RESP_CONNECT_ERROR respMsg:@"连接失败" respData:@{}]);
        }
    }else{
        self.connectStatus = XLSocketConnectStatus_Connected;
        XLLog(@"----------------连接服务器成功----------------");
        if (successCB) {
            successCB([XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"连接成功" respData:@{}]);
        }
    }
}
- (void)sendMessageWithData:(NSData *)data
{
    [_xlCommunicateSocket writeData:data withTimeout:1 tag:1];
}
#pragma mark - Geter and Setter
- (NSMutableArray *)delegates{
    if (!_delegates) {
        _delegates = [NSMutableArray array];
    }
    return _delegates;
}
#pragma mark - 代理
- (void)addDelegate:(id<XLSocketHandlerDelegate>)delegate delegateQueue:(dispatch_queue_t)queue;
{
    if ([self.delegates containsObject:delegate] == NO) {
        [self.delegates addObject:delegate];
    }
}
- (void)removeDelegate:(id<XLSocketHandlerDelegate>)delegate
{
    if ([self.delegates containsObject:delegate] == YES) {
        [self.delegates removeObject:delegate];
    }
}

#pragma mark - socket连接管理
#pragma mark 主动断开连接
- (void)executeDisconnectServer
{
    //更新sokect连接状态
    _connectStatus = XLSocketConnectStatus_UnConnected;
    [self disconnect];
}

#pragma mark 连接中断
- (void)serverInterruption
{
    //更新soceket连接状态
    _connectStatus = XLSocketConnectStatus_UnConnected;
    [self disconnect];
}

- (void)disconnect
{
    //断开连接
    [_xlCommunicateSocket disconnect];
}
- (void)beginReadDataTimeOut:(long)timeOut tag:(long)tag
{
    [_xlCommunicateSocket readDataWithTimeout:[[XLConfigManager share] getTimeout] tag:tag];
}
#pragma mark -  GCDAsyncSocketDelegate
#pragma mark - TCP连接成功建立 ,配置SSL 相当于https 保证安全性 , 这里是单向验证服务器地址 , 仅仅需要验证服务器的IP即可
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    [self beginReadDataTimeOut:-1 tag:0];
}

#pragma mark TCP成功获取安全验证
- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    //开启读入流
    [self beginReadDataTimeOut:-1 tag:0];
}
#pragma mark 接收到消息
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    // 调用数据解析方法解析数据
    NSString *hexString = [TransformNSString hexStringFromData:data];
    XLLog(@"--socket--Read:%@",hexString);
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(didReceivedXunLianResponseMessageWithHexString:)]) {
            [delegate didReceivedXunLianResponseMessageWithHexString:hexString];
        }
    }
}
- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    XLLog(@"进度 %lu", partialLength);
}
#pragma mark 写入数据成功 , 重新开启允许读取数据
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [self beginReadDataTimeOut:-1 tag:0];
}
#pragma mark TCP已经断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    XLLog(@"连接断开了---------------------------------");
    //置为未连接状态
    _connectStatus  = XLSocketConnectStatus_UnConnected;
    // 暂不处理
}
#pragma mark 发送消息超时
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    //处理发送消息超时
    XLLog(@"写超时了--------------------------------------");
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(socketHandlerErrorWithModel:)]) {
            XLResponseModel *errorModel = [XLResponseModel createRespMsgWithCode:RESP_WRITE_TIMEOUT respMsg:@"socket write timeout" respData:@{}];
            [delegate socketHandlerErrorWithModel:errorModel];
        }
    }
    return -1;
}
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    XLLog(@"读超时了--------------------------------------");
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(socketHandlerErrorWithModel:)]) {
            XLResponseModel *errorModel = [XLResponseModel createRespMsgWithCode:RESP_READ_TIMEOUT respMsg:@"socket write timeout" respData:@{}];
            [delegate socketHandlerErrorWithModel:errorModel];
        }
    }
    return -1;
}
@end
