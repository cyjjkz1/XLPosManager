//
//  XLPOSManager.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/12.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLPOSManager.h"
#import "Util.h"
#import "BTDeviceFinder.h"
#import "QPOSService.h"
#import "XLError.h"
#import "XLKit.h"
#import <UIKit/UIKit.h>
#import "DUKPT_2009_CBC.h"
#import "DecryptTLV.h"
#import "XLAuthPublicModel.h"
#import "XLISO8583Handler.h"
#import "XLPayManager.h"
#import "XLConfigManager.h"
#import "BerTlvUmbrella.h"
#import "TransformNSString.h"

@interface XLPOSManager()<BluetoothDelegate2Mode,QPOSServiceListener>
@property (nonatomic, strong) BTDeviceFinder *btDeviceFinder;
@property (nonatomic, copy) OnSearchOneDeviceCB searchOneDeviceCB;
@property (nonatomic, copy) OnSearchCompleteCB searchCompleteCB;
@property (nonatomic, strong) QPOSService *xlMQposService;
@property (nonatomic, copy) NSString *currencyCode;
@property (nonatomic, copy) NSString *tradeAmount;
@property (nonatomic, copy) NSString *currentTerminalTime;
@property (nonatomic, assign) TransactionType transactionType;
@property (nonatomic, strong) NSArray *cardTypeArray;
@property (nonatomic, copy) NSString *batchId;
@property (nonatomic, copy) NSString *tradeNumber;

@property (nonatomic, copy) NSString *originBatchId;
@property (nonatomic, copy) NSString *originTradeNumber;
@property (nonatomic, copy) NSString *originTradeDateMMdd;
@property (nonatomic, copy) NSString *bankCardNumber;
@property (nonatomic, copy) NSString *capQueryNumber;

@property (nonatomic, copy) NSDictionary *iso8583FieldsParams;
@property (nonatomic, copy) NSDictionary *originTradeParams;
@property (nonatomic, copy) NSDictionary *originCapRespParams;

@property (nonatomic, copy) NSString *capRespMacHexStr;

@property (nonatomic, copy) HandleResultBlock connectDeviceSuccessCB;
@property (nonatomic, copy) HandleResultBlock connectDeviceFailedCB;
@property (nonatomic, copy) HandleResultBlock disconnectDeviceSuccessCB;
@property (nonatomic, copy) HandleResultBlock directConnectSuccessCB;

@property (nonatomic, copy) HandleResultBlock successCB;
@property (nonatomic, copy) HandleResultBlock progressCB;
@property (nonatomic, copy) HandleResultBlock failedCB;
@property (nonatomic, assign) XLPayBusinessType posTradeType;
@property (nonatomic, strong) NSArray *tagsArray;
@property (nonatomic, assign) DoTradeResult doTradeResult;

@end


@implementation XLPOSManager
+ (instancetype)shareInstance
{
    static XLPOSManager *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[XLPOSManager alloc] init];
        handler.btDeviceFinder = [BTDeviceFinder new];
        [handler.btDeviceFinder setBluetoothDelegate2Mode:handler];
        handler.xlMQposService = [QPOSService sharedInstance];
        [handler.xlMQposService setDelegate:handler];
        [handler.xlMQposService setQueue:nil];
        [handler.xlMQposService setPosType:PosType_BLUETOOTH_2mode];
        handler.currencyCode = [[XLConfigManager share] getCurrency];
        handler.transactionType = TransactionType_GOODS;
        handler.posTradeType = XLPayBusinessTypeConsume;
        handler.tagsArray = @[@"9F26", @"9F27", @"9F10", @"9F37", @"9F36",
                              @"95", @"9A", @"9C", @"9F02", @"5F2A",
                              @"82", @"9F1A", @"9F03", @"9F33"];
        
    });
    return handler;
}
- (BOOL)setupDefautDeviceName:(NSString *) deviceName
{
    if (!deviceName || deviceName.length <= 0) {
        return NO;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:deviceName forKey:kDEFAULT_DEVICE_NAME];
    return [userDefaults synchronize];
    
}
- (void)getCurrentPOSInfo
{
    [[QPOSService sharedInstance] getQPosInfo];
}
-(void)onQposInfoResult: (NSDictionary*)posInfoData{
    NSLog(@"POSinfo = %@", posInfoData);
}
/**
 *    @brief    查询设备
 *
 *    @param     timeout     查询超时
 *    @param     searchOneDeviceCB     查询到一个设备回调
 *    @param     searchCompleteCB     查询设备完成回调
 
 */
#pragma mark - 搜索设备相关
- (void) startSearchDev:(NSInteger)timeout
   searchOneDeviceBlcok:(OnSearchOneDeviceCB) searchOneDeviceCB
          completeBlock:(OnSearchCompleteCB)searchCompleteCB
{
    [XLPOSManager shareInstance].searchOneDeviceCB = [searchOneDeviceCB copy];
    [XLPOSManager shareInstance].searchCompleteCB = [searchCompleteCB copy];
//    if ([[XLPOSManager shareInstance].btDeviceFinder getCBCentralManagerState] == CBCentralManagerStateUnknown) {
//        while ([[XLPOSManager shareInstance].btDeviceFinder getCBCentralManagerState]!= CBCentralManagerStatePoweredOn) {
//            NSLog(@"Bluetooth state is not power on");
//            [self sleepMs:timeout];
//            if(delay++==timeout){
//                if ([XLPOSManager shareInstance].searchCompleteCB) {
//                    [[XLPOSManager shareInstance].btDeviceFinder stopQPos2Mode];
//                    [[XLPOSManager shareInstance].btDeviceFinder setBluetoothDelegate2Mode:nil];
//                    XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_BLUETOOTH_ERROR respMsg:@"蓝牙处于未开启状态"];
//                    startCallBack([XLPOSManager shareInstance].searchCompleteCB, model);
//                    [XLPOSManager shareInstance].searchCompleteCB = nil;
//                }
//                return;
//            }
//        }
//    }
    [[XLPOSManager shareInstance].btDeviceFinder setBluetoothDelegate2Mode:[XLPOSManager shareInstance]];
    [[XLPOSManager shareInstance].btDeviceFinder scanQPos2Mode:timeout];
}
- (void)sleepMs: (NSInteger)msec {
    NSTimeInterval sec = (msec / 1000.0f);
    [NSThread sleepForTimeInterval:sec];
}
/**
 *    @brief    停止查询设备
 *
 *
 */
#pragma mark BluetoothDelegate2Mode 停止搜索蓝牙设备
- (void) stopSearchDev
{
    XLLog(@"停止搜索POS");
    [[XLPOSManager shareInstance].btDeviceFinder stopQPos2Mode];
}
#pragma mark BluetoothDelegate2Mode 搜索蓝压设备回调
-(void)onBluetoothName2Mode:(NSString *)bluetoothName
{
    if (bluetoothName && bluetoothName.length > 0) {
        XLLog(@"搜到一个蓝牙设备");
        //搜到一个POS的回调
        //连接蓝牙要使用返回的名字
        NSDictionary *device = @{@"pos_name": bluetoothName};
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS
                                                                respMsg:@"搜到一个蓝牙设备"
                                                               respData:device];
        if ([XLPOSManager shareInstance].searchOneDeviceCB) {
            startCallBack([XLPOSManager shareInstance].searchOneDeviceCB, model);
        }
    }
    
}
#pragma mark BluetoothDelegate2Mode 搜索蓝压设备回调
-(void)finishScanQPos2Mode
{
    XLLog(@"搜索完毕");
    if ([XLPOSManager shareInstance].searchCompleteCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"搜索完毕"];
        startCallBack([XLPOSManager shareInstance].searchCompleteCB, model);
        [XLPOSManager shareInstance].searchOneDeviceCB = nil;
        [XLPOSManager shareInstance].searchCompleteCB = nil;
    }
}
#pragma mark BluetoothDelegate2Mode 搜索蓝压设备回调
-(void)bluetoothIsPowerOff2Mode
{
    XLLog(@"蓝牙处于未开启状态");
    [[XLPOSManager shareInstance].btDeviceFinder stopQPos2Mode];
    [[XLPOSManager shareInstance].btDeviceFinder setBluetoothDelegate2Mode:nil];
    if ([XLPOSManager shareInstance].searchCompleteCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_BLUETOOTH_ERROR respMsg:@"蓝牙处于未开启状态"];
        startCallBack([XLPOSManager shareInstance].searchCompleteCB, model);
        [XLPOSManager shareInstance].searchOneDeviceCB = nil;
        [XLPOSManager shareInstance].searchCompleteCB = nil;
    }
    //蓝牙状态为关闭的回调
}
#pragma mark BluetoothDelegate2Mode 搜索蓝压设备回调
-(void)bluetoothIsPowerOn2Mode
{
    //蓝牙状态为打开的回调
    XLLog(@"蓝牙状态为开启");
}

#pragma mark - 连接设备
/**
 *    @brief    连接POS，该接口需要先走搜索，以便发现设备，然后用设备识别码连接设备
 *    @param     identifier     设备识别码
 *    @param     successCB     成功回调
 *    @param     failedCB     失败回调
 */
- (void)openDevice:(NSString *)identifier
      successBlock:(HandleResultBlock)successCB
       failedBlock:(HandleResultBlock)failedCB;

{
    if (identifier && identifier.length > 0) {
        [XLPOSManager shareInstance].connectDeviceSuccessCB = successCB;
        [XLPOSManager shareInstance].connectDeviceFailedCB = failedCB;
        [[QPOSService sharedInstance] connectBT:identifier];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"连接设备名不能为空"];
        startCallBack(failedCB, model);
    }
    
}
/**
 *    @brief    如果已经有POS识别码，直接连接POS，这个不用先走搜索再连接
 *    @param    identifier   设备识别码
 *    @param    successCB    成功回调
 *    @param    failedCB     失败回调
 */
- (void)connectDeviceWithIdentifier:(NSString *)identifier
                       successBlock:(HandleResultBlock)successCB
                        failedBlock:(HandleResultBlock)failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    if (identifier && identifier.length > 0) {
        [XLPOSManager shareInstance].directConnectSuccessCB = successCB;
        [XLPOSManager shareInstance].connectDeviceFailedCB = failedCB;
        [[QPOSService sharedInstance] connectBluetoothNoScan:identifier];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"连接设备名不能为空"];
        startCallBack(failedCB, model);
    }
}

-(void) onRequestQposConnected{
    XLLog(@"设备连接成功");
    [NSThread sleepForTimeInterval:1.0];
    XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"设备连接成功"];
    if ([XLPOSManager shareInstance].connectDeviceSuccessCB) {
        startCallBack([XLPOSManager shareInstance].connectDeviceSuccessCB, model);
        [XLPOSManager shareInstance].connectDeviceSuccessCB = nil;
    }
    if ([XLPOSManager shareInstance].directConnectSuccessCB) {
        startCallBack([XLPOSManager shareInstance].directConnectSuccessCB, model);
        [XLPOSManager shareInstance].directConnectSuccessCB = nil;
    }
}
-(void) onRequestQposDisconnected{
    XLLog(@"设备断开连接");
    if ([XLPOSManager shareInstance].disconnectDeviceSuccessCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"设备断开连接"];
        startCallBack([XLPOSManager shareInstance].disconnectDeviceSuccessCB, model);
        [XLPOSManager shareInstance].disconnectDeviceSuccessCB = nil;
    }
    
    //主动断开连接也要走这个回调
}
-(void) onRequestNoQposDetected{
    XLLog(@"没有POS被检测到，请先搜索POS");
    if ([XLPOSManager shareInstance].connectDeviceFailedCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_CONNECT_ERROR respMsg:@"没有POS被检测到，请先搜索POS"];
        startCallBack([XLPOSManager shareInstance].connectDeviceFailedCB, model);
        [XLPOSManager shareInstance].connectDeviceFailedCB = nil;
    }
    if ([XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeCheckMac ||
        [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeCalcuateMac) {
        // 在CAP返回应答包的时候，如果是交易类型需要进行mac校验，如果这个时候POS是没有连接的，POS回调该接口，
        // 同时回调XLPayManager 失败的回调
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_DISCONNECTED respMsg:@"没有POS被检测到，请先搜索POS，请重试"];
        HandleResultBlock block = [[XLPayManager shareInstance] getPayManagerFailedCB];
        if (block) {
            startCallBack(block, model);
        }
    }
}
/**
 *    @brief    关闭设备
 */
- (void)closeDevicesuccessBlock:(HandleResultBlock)successCB
{
    [[QPOSService sharedInstance] resetPosStatus];
    [[QPOSService sharedInstance] disconnectBT];
}


/**
 *    @brief    是否连接
 *
 *    @return   设备是否连接
 */
- (BOOL)isConnectToDevice
{
    return NO;
}
#pragma mark - 设置主密钥
/**
 *    @brief    设置主密钥
 *    @param     tmkModel     主密钥model 包含用原始tmk加密的tmk和checkvalue
 *    @param     successCB     成功回调
 *    @param     failedCB     失败回调
 */
#pragma mark 调用POS API设置主密钥
- (void)setupInDeviceWithMasterKeyHexStirng:(XLTMKModel *) tmkModel
                               successBlock:(HandleResultBlock)successCB
                                failedBlock:(HandleResultBlock)failedCB
{
    if (!successCB ||!failedCB) {
        return;
    }
    if (tmkModel) {
        [XLPOSManager shareInstance].successCB = [successCB copy];
        [XLPOSManager shareInstance].failedCB = [failedCB copy];
        [[QPOSService sharedInstance] setMasterKey:tmkModel.cipherTextTmk checkValue:tmkModel.checkValue keyIndex:0 delay:5];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误"];
        startCallBack(failedCB, model);
    }
}
#pragma mark 设置主密钥的回调
- (void)onReturnSetMasterKeyResult: (BOOL)isSuccess{
    if(isSuccess){
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"主密钥设置成功"];
        if ([XLPOSManager shareInstance].successCB) {
            startCallBack([XLPOSManager shareInstance].successCB, model);
            [XLPOSManager shareInstance].successCB = nil;
        }
    }else{
        [[QPOSService sharedInstance] resetPosStatus];
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_SET_MASTER_KER_ERROR respMsg:@"主密钥设置失败"];
        if ([XLPOSManager shareInstance].failedCB) {
            startCallBack([XLPOSManager shareInstance].failedCB, model);
            [XLPOSManager shareInstance].failedCB = nil;
        }
    }
}
#pragma mark - 设置工作密钥
/**
 *    @brief    设置工作密钥
 *    @param     successCB     成功回调
 *    @param     failedCB     失败回调
 */
#pragma mark 调用POS API设置工作密钥
- (void)setupInDeviceWithWorkKeyHexStirng:(XLWorkKeyModel *)workModel
                             successBlock:(HandleResultBlock)successCB
                              failedBlock:(HandleResultBlock)failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    if (workModel) {
        [XLPOSManager shareInstance].successCB = [successCB copy];
        [XLPOSManager shareInstance].failedCB = [failedCB copy];
        [[QPOSService sharedInstance] udpateWorkKey:workModel.encPinKey
                                        pinKeyCheck:workModel.encPinKeyCV
                                           trackKey:workModel.encTdkKey
                                      trackKeyCheck:workModel.encTdkKeyCV
                                             macKey:workModel.encMacKey
                                        macKeyCheck:workModel.encMacKeyCV
                                           keyIndex:0 delay:5];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误"];
        startCallBack(failedCB, model);
    }
}
-(void) onRequestUpdateWorkKeyResult:(UpdateInformationResult)updateInformationResult
{
    NSString *msg = nil;
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        msg = @"更新工作密钥成功";
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:msg];
        if ([XLPOSManager shareInstance].successCB) {
            startCallBack([XLPOSManager shareInstance].successCB, model);
            [XLPOSManager shareInstance].successCB = nil;
        }
    }else{
        if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
            msg = @"更新工作密钥失败";
        }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
            msg = @"工作密钥长度错误";
        }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
            msg = @"工作密钥验证错误";
        }else{
            msg = @"更新工作密钥失败";
        }
        [[QPOSService sharedInstance] resetPosStatus];
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_SET_WORK_KER_ERROR respMsg:msg];
        if ([XLPOSManager shareInstance].failedCB) {
            startCallBack([XLPOSManager shareInstance].failedCB, model);
            [XLPOSManager shareInstance].failedCB = nil;
        }
    }
}

/**
 *    @brief    POS 重置
 */
- (void)resetXLDeviceWithSuccessBlock:(HandleResultBlock)successCB
                          failedBlock:(HandleResultBlock)failedCB
{
    [[QPOSService sharedInstance] getQPosId];
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
}

-(void) onQposIdResult: (NSDictionary*)posId{
    NSString *aStr = [@"posId:" stringByAppendingString:posId[@"posId"]];
    
    NSString *temp = [@"psamId:" stringByAppendingString:posId[@"psamId"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"merchantId:" stringByAppendingString:posId[@"merchantId"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"vendorCode:" stringByAppendingString:posId[@"vendorCode"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"deviceNumber:" stringByAppendingString:posId[@"deviceNumber"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"psamNo:" stringByAppendingString:posId[@"psamNo"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"isSupportNFC:" stringByAppendingString:posId[@"isSupportNFC"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    XLLog(aStr);
    if ([XLPOSManager shareInstance].successCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"重置刷卡器成功"];
        startCallBack([XLPOSManager shareInstance].successCB, model);
    }
    
}
#pragma mark - 发起交易
/**
 *    @brief    发起交易 在成功的回调中会返回XLResponseModel, data为原始交易数据，需缓存，当发生冲正的情况是，需要用原交易数据冲正，XLPackModel为原始数据封包，上送CAP
 *    @param    amount  金额 以分为单位
 *    @param     successCB    成功回调
 *    @param     batchId      交易批次号 6位数字字符串
 *    @param     tradeNumber  交易流水号 6位数字字符串
 *    @param     progressCB    进展回调 现在执行到哪步了，需要提供相关参数在这个回调里面会说明
 *    @param     failedCB     失败回调
 */
- (void)doTradeWithAmount:(NSString *)amount
                  batchId:(NSString *) batchId
              tradeNumber:(NSString *) tradeNumber
             successBlock:(HandleResultBlock)successCB
            progressBlock:(HandleResultBlock)progressCB
              failedBlock:(HandleResultBlock)failedCB
{
    if (!successCB || !progressCB || !failedCB) {
        return;
    }
    if ([amount integerValue] <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(金额不能为空)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:tradeNumber] || tradeNumber.length != 6 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(合作方流水号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:batchId] || batchId.length != 6 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(批次号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    [XLPOSManager shareInstance].tradeAmount = amount;
    [XLPOSManager shareInstance].batchId = batchId;
    [XLPOSManager shareInstance].tradeNumber = tradeNumber;
    
    [XLPOSManager shareInstance].currencyCode = [[XLConfigManager share] getCurrency];
    [XLPOSManager shareInstance].currentTerminalTime = [[XLKit yMdHmsFormatter] stringFromDate:[NSDate date]];
    [XLPOSManager shareInstance].transactionType = TransactionType_GOODS;
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeConsume;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = [progressCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [[QPOSService sharedInstance] setFormatID:@"0008"];
    [[QPOSService sharedInstance] doTrade:50];
}
/**
 *    @brief    撤销交易 在成功的回调中会返回XLResponseModel, data为原始交易数据，需缓存，当发生冲正的情况是，需要用原交易数据冲正,， XLPackModel为原始数据封包，上送CAP
 *    @param    amount  金额 以分为单位
 *    @param    batchId      交易批次号 6位数字字符串
 *    @param    tradeNumber  交易流水号 6位数字字符串
 *    @param    originBatchId 原始订单号
 *    @param    originTradeNumber 原始流水号
 *    @param    capQueryNumber    CAP检索参考号
 *    @param    successCB    成功回调
 *    @param    progressCB    进展回调 现在执行到哪步了，需要提供相关参数在这个回调里面会说明
 *    @param    failedCB     失败回调
 */
- (void)doCancelWithAmount:(NSString *) amount
                   batchId:(NSString *) batchId
               tradeNumber:(NSString *) tradeNumber
             originBatchId:(NSString *) originBatchId
         originTradeNumber:(NSString *) originTradeNumber
            capQueryNumber:(NSString *) capQueryNumber
              successBlock:(HandleResultBlock) successCB
             progressBlock:(HandleResultBlock) progressCB
               failedBlock:(HandleResultBlock) failedCB;
{
    if (!successCB || !progressCB || !failedCB) {
        return;
    }
    if ([amount integerValue] <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(金额不能为空)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:tradeNumber] || tradeNumber.length != 6) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(合作方流水号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:batchId] || batchId.length != 6 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(批次号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:originBatchId] || originBatchId.length != 6) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原交易批次号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    if (![XLKit isIntegerValue:originTradeNumber] || originTradeNumber.length != 6) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(合作方流水号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    [XLPOSManager shareInstance].tradeAmount = amount;
    [XLPOSManager shareInstance].batchId = batchId;
    [XLPOSManager shareInstance].tradeNumber = tradeNumber;
    [XLPOSManager shareInstance].originBatchId = originBatchId;
    [XLPOSManager shareInstance].originTradeNumber = originTradeNumber;
    [XLPOSManager shareInstance].capQueryNumber = capQueryNumber;
    
    [XLPOSManager shareInstance].currencyCode = [[XLConfigManager share] getCurrency];
    [XLPOSManager shareInstance].currentTerminalTime = [[XLKit yMdHmsFormatter] stringFromDate:[NSDate date]];
    [XLPOSManager shareInstance].transactionType = TransactionType_GOODS;
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeConsumeCancel;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = [progressCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [[QPOSService sharedInstance] setFormatID:@"0008"];
    [[QPOSService sharedInstance] doTrade:50];
}

/**
 *    @brief    无卡退货 在成功的回调中会返回XLResponseModel, data为原始交易数据，需缓存，当发生冲正的情况是，需要用原交易数据冲正,， XLPackModel为原始数据封包，上送CAP
 *    @param    amount  金额 以分为单位
 *    @param    batchId      交易批次号 6位数字字符串
 *    @param    tradeNumber  交易流水号 6位数字字符串
 *    @param    bankCardNumber        银行卡号
 *    @param    originBatchId 原始订单号
 *    @param    originTradeNumber 原始流水号
 *    @param    dateMMdd          原始交易日期 4位 MMdd 如：1016  10月16号
 *    @param    successCB    成功回调
 *    @param    failedCB     失败回调
 */
- (void)doNoCardReturnGoodsWithAmount:(NSString *) amount
                              batchId:(NSString *) batchId
                          tradeNumber:(NSString *) tradeNumber
                       bankCardNumber:(NSString *) bankCardNumber
                        originBatchId:(NSString *) originBatchId
                    originTradeNumber:(NSString *) originTradeNumber
                             dateMMdd:(NSString *) dateMMdd
                       capQueryNumber:(NSString *) capQueryNumber
                         successBlock:(HandleResultBlock) successCB
                          failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    if ([amount integerValue] <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(金额不能为空)"];
        startCallBack(failedCB, model);
        return;
    }

    if (![XLKit isIntegerValue:batchId] || batchId.length != 6 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(批次号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:tradeNumber] || tradeNumber.length != 6) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(合作方流水号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:bankCardNumber] || bankCardNumber.length < 12 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(银行卡号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:originBatchId] || originBatchId.length != 6) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原交易批次号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:originTradeNumber] || originTradeNumber.length != 6) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原合作方流水号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:capQueryNumber] || capQueryNumber.length != 12) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(CAP检索参考号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:dateMMdd] || dateMMdd.length != 4) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原交易日期不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    [XLPOSManager shareInstance].tradeAmount = amount;
    [XLPOSManager shareInstance].batchId = batchId;
    [XLPOSManager shareInstance].tradeNumber = tradeNumber;
    [XLPOSManager shareInstance].originBatchId = originBatchId;
    [XLPOSManager shareInstance].originTradeNumber = originTradeNumber;
    [XLPOSManager shareInstance].originTradeDateMMdd = dateMMdd;
    [XLPOSManager shareInstance].bankCardNumber = bankCardNumber;
    [XLPOSManager shareInstance].capQueryNumber = capQueryNumber;
    
    [XLPOSManager shareInstance].currencyCode = [[XLConfigManager share] getCurrency];
    [XLPOSManager shareInstance].currentTerminalTime = [[XLKit yMdHmsFormatter] stringFromDate:[NSDate date]];
    [XLPOSManager shareInstance].transactionType = TransactionType_GOODS;
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeReturnGoods;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [[XLPOSManager shareInstance] doReturnGoodsFillISO8583ParamsWithModel: nil];
}
/**
 *    @brief    有卡退货 在成功的回调中会返回XLResponseModel, data为原始交易数据，需缓存，当发生冲正的情况是，需要用原交易数据冲正,， XLPackModel为原始数据封包，上送CAP
 *    @param    amount  金额 以分为单位
 *    @param    batchId      交易批次号 6位数字字符串
 *    @param    tradeNumber  交易流水号 6位数字字符串
 *    @param    originBatchId 原始订单号
 *    @param    originTradeNumber 原始流水号
 *    @param    dateMMdd          原始交易日期 4位 MMdd 如：1016  10月16号
 *    @param    successCB    成功回调
 *    @param    progressCB    进展回调 现在执行到哪步了，需要提供相关参数在这个回调里面会说明
 *    @param    failedCB     失败回调
 */
- (void)doHaveCardReturnGoodsWithAmount:(NSString *) amount
                                batchId:(NSString *) batchId
                            tradeNumber:(NSString *) tradeNumber
                          originBatchId:(NSString *) originBatchId
                      originTradeNumber:(NSString *) originTradeNumber
                               dateMMdd:(NSString *) dateMMdd
                         capQueryNumber:(NSString *) capQueryNumber
                           successBlock:(HandleResultBlock) successCB
                          progressBlock:(HandleResultBlock) progressCB
                            failedBlock:(HandleResultBlock) failedCB{
    if (!successCB || !failedCB) {
        return;
    }
    if ([amount integerValue] <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(金额不能为空)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:batchId] || batchId.length != 6 ) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(批次号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:tradeNumber] || tradeNumber.length != 6) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(合作方流水号不合法)"];
        startCallBack(failedCB, model);
        return;
    }
    
    if (![XLKit isIntegerValue:originBatchId] || originBatchId.length != 6) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原交易批次号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:capQueryNumber] || capQueryNumber.length != 12) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(CAP检索参考号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:originTradeNumber] || originTradeNumber.length != 6) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原合作方流水号不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    if (![XLKit isIntegerValue:dateMMdd] || dateMMdd.length != 4) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(原交易日期不合法)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    [XLPOSManager shareInstance].tradeAmount = amount;
    [XLPOSManager shareInstance].batchId = batchId;
    [XLPOSManager shareInstance].tradeNumber = tradeNumber;
    
    [XLPOSManager shareInstance].originBatchId = originBatchId;
    [XLPOSManager shareInstance].originTradeNumber = originTradeNumber;
    [XLPOSManager shareInstance].originTradeDateMMdd = dateMMdd;
    [XLPOSManager shareInstance].capQueryNumber = capQueryNumber;
    
    [XLPOSManager shareInstance].currencyCode = [[XLConfigManager share] getCurrency];
    [XLPOSManager shareInstance].currentTerminalTime = [[XLKit yMdHmsFormatter] stringFromDate:[NSDate date]];
    [XLPOSManager shareInstance].transactionType = TransactionType_GOODS;
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeReturnGoods;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = [progressCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [[QPOSService sharedInstance] setFormatID:@"0008"];
    [[QPOSService sharedInstance] doTrade:50];
}
- (void)doReturnGoodsFillISO8583ParamsWithModel:(XLBankCardModel *) mcrModel{
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *terminalId = [userDefaults valueForKey:kTERMINALID_USERDEFAULT_KEY];
    NSString *merchatId = [userDefaults valueForKey:kMERCHANTID_USERDEFAULT_KEY];
    if (!terminalId || !merchatId) {
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
        return;
    }
    NSDictionary *fixedParam = @{
                                 @"0": @"0220",
                                 @"3": @"200000",
                                 @"22": @"012",
                                 @"25":  @"00",
                                 @"41":  terminalId,
                                 @"42":  merchatId,
                                 @"49":  [[XLConfigManager share] getCurrency],
                                 @"64": @"FFFFFFFFFFFFFFFF"
                                 };
    [paramDict setDictionary:fixedParam];
    NSString *field4 = @"000000000000";
    NSUInteger amountLen = [XLPOSManager shareInstance].tradeAmount.length;
    field4 = [field4 stringByReplacingCharactersInRange:NSMakeRange(field4.length - amountLen, amountLen) withString:[XLPOSManager shareInstance].tradeAmount];
    [paramDict setObject:field4 forKey:@"4"];
    [paramDict setObject:[XLPOSManager shareInstance].tradeNumber forKey:@"11"];
    if (mcrModel) {
        // 二磁明文数据
        if ([mcrModel.track2Length integerValue] > 0) {
            [paramDict setValue:mcrModel.encTrack2  forKey:@"35"];
        }else{
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_LACK_TRACK2_ERROR respMsg:@"缺少卡磁数据"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
            return;
        }
        // 三磁明文数据 有就传
        if ([mcrModel.track3Length integerValue] > 0) {
            [paramDict setValue:mcrModel.encTrack3 forKey:@"36"];
        }
        // 免密交易 和 密码交易 如果有卡密返回就是走密码交易，如果没有密码返回就走免密交易
        // @"60": @"2201024900050", 最后一位表示免密，以前传13位，默认补位
        NSString *readCardAbility = @"6";
        if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
            readCardAbility = @"6";
        }else{
            readCardAbility = @"5";
        }
        if (mcrModel.pinblock && mcrModel.pinblock.length > 0) {
            [paramDict setValue:@"021" forKey:@"22"]; //刷卡，且pin可输入
            NSString *field60 = [NSString stringWithFormat:@"25%@000%@01", [XLPOSManager shareInstance].batchId, readCardAbility];
            [paramDict setValue:field60 forKey:@"60"];
            // 密码交易需要传递卡密
            [paramDict setValue:mcrModel.pinblock forKey:@"52"];
            [paramDict setValue:@"2600000000000000" forKey:@"53"];//带主账号信息 双倍长密钥 磁道不加密
        }else{
            [paramDict setValue:@"022" forKey:@"22"]; //刷卡，无pin
            NSString *field60 = [NSString stringWithFormat:@"25%@000%@00", [XLPOSManager shareInstance].batchId, readCardAbility];
            [paramDict setValue:field60 forKey:@"60"];
        }
        // IC卡交易相关
        if (mcrModel.iccdata && mcrModel.iccdata.length > 0) {
            //IC卡交易 重新设置22域数据
            if (mcrModel.pinblock && mcrModel.pinblock.length > 0) {
                if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
                    [paramDict setValue:@"071" forKey:@"22"];
                }else{
                    [paramDict setValue:@"051" forKey:@"22"];
                }
            }else{
                if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
                    [paramDict setValue:@"072" forKey:@"22"];
                }else{
                    [paramDict setValue:@"050" forKey:@"22"];
                }
            }
            [paramDict setValue:@"001" forKey:@"23"];
//            [paramDict setValue:mcrModel.iccdata forKey:@"55"];
        }
    }else{
        NSString *field60 = [NSString stringWithFormat:@"25%@0000", [XLPOSManager shareInstance].batchId];
        [paramDict setValue:field60 forKey:@"60"];
        [paramDict setValue:[XLPOSManager shareInstance].bankCardNumber forKey:@"2"];
    }
    [paramDict setObject:[XLPOSManager shareInstance].capQueryNumber forKey:@"37"];
    NSString *field61 = [NSString stringWithFormat:@"%@%@%@", [XLPOSManager shareInstance].originBatchId, [XLPOSManager shareInstance].originTradeNumber, [XLPOSManager shareInstance].originTradeDateMMdd];
    [paramDict setValue:field61 forKey:@"61"];
    [paramDict setObject:@"UPI" forKey:@"63"];
    XLLog(@"ISO fileds params = %@", paramDict);
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:paramDict completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [[XLPOSManager shareInstance] calMacWithRequestHexString:tempStr];
        }else{
            if ([XLPOSManager shareInstance].failedCB) {
                startCallBack([XLPOSManager shareInstance].failedCB, respModel);
                [XLPOSManager shareInstance].failedCB = nil;
            }
        }
    }];
}
/**
 *    @brief    消费冲正
 *    @param    tradeISO8583Params  交易的8583参数 从原交易获取数据，不用在刷卡
 *    @param     successCB    成功回调
 *    @param     progressCB    进展回调 现在执行到哪步了，需要提供相关参数在这个回调里面会说明
 *    @param     failedCB     失败回调
 */
- (void)doTradeReverseWithOriginISO8583Params:(NSDictionary *) tradeISO8583Params
                                 successBlock:(HandleResultBlock) successCB
                                progressBlock:(HandleResultBlock) progressCB
                                  failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !progressCB || !failedCB) {
        return;
    }
    if (!tradeISO8583Params || [tradeISO8583Params count] == 0) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(缺少消费冲正原始交易数据)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeConsumeCancel;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = [progressCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    
    NSMutableDictionary *fieldsParam = [NSMutableDictionary dictionaryWithDictionary:tradeISO8583Params];
    [fieldsParam setValue:@"0400" forKey:@"0"]; // 修改交易类型为冲正
    [fieldsParam setValue:@"06" forKey:@"39"];  // 冲正原因
    
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:fieldsParam completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [self calMacWithRequestHexString:tempStr];
        }else{
            if ([XLPOSManager shareInstance].failedCB) {
                startCallBack(failedCB, respModel);
                [XLPOSManager shareInstance].failedCB = nil;
            }
        }
    }];
}

/**
 *    @brief    消费撤销冲正
 *    @param    cancelISO8583Params  撤销的8583参数 从原撤销交易获取数据，不用在刷卡
 *    @param     successCB    成功回调
 *    @param     progressCB    进展回调 现在执行到哪步了，需要提供相关参数在这个回调里面会说明
 *    @param     failedCB     失败回调
 */
- (void)doCancelReverseOriginISO8583Params:(NSDictionary *) cancelISO8583Params
                              successBlock:(HandleResultBlock) successCB
                             progressBlock:(HandleResultBlock) progressCB
                               failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !progressCB || !failedCB) {
        return;
    }
    if (!cancelISO8583Params || [cancelISO8583Params count] == 0) {
        if (failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(缺少消费撤销冲正原始交易数据)"];
            startCallBack(failedCB, model);
        }
        return;
    }
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeConsumeCancel;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = [progressCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    
    NSMutableDictionary *fieldsParam = [NSMutableDictionary dictionaryWithDictionary:cancelISO8583Params];
    [fieldsParam setValue:@"0400" forKey:@"0"]; // 修改交易类型为冲正
    [fieldsParam setValue:@"06" forKey:@"39"]; // 冲正原因
    
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:fieldsParam completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [self calMacWithRequestHexString:tempStr];
        }else{
            if ([XLPOSManager shareInstance].failedCB) {
                startCallBack([XLPOSManager shareInstance].failedCB, respModel);
                [XLPOSManager shareInstance].failedCB = nil;
            }
        }
    }];
}


/**
 *    @brief    计算返回报文的Mac
 *    @param    respMessageHexStr  交易返回报文的16进制串
 *    @param     successCB    成功回调
 *    @param     failedCB     失败回调
 */
- (void)checkMacWithResponseMessage:(NSString *) respMessageHexStr
                           successBlock:(HandleResultBlock) successCB
                            failedBlock:(HandleResultBlock) failedCB
{
    if (!respMessageHexStr || respMessageHexStr.length <= 26) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(缺少计算mac的原始数据)"];
        startCallBack(failedCB, model);
        return;
    }
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeCheckMac;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    
//  对返回的报文要做掐头去尾
    NSString *iso8583Data = [respMessageHexStr substringWithRange:NSMakeRange(26, respMessageHexStr.length - 26)];
    NSString *noMacIso8583Data = [iso8583Data substringWithRange:NSMakeRange(0, iso8583Data.length - 16)];
    NSString *mac = [respMessageHexStr substringWithRange:NSMakeRange(respMessageHexStr.length - 16, 16)];
    
    [XLPOSManager shareInstance].capRespMacHexStr = mac;
    [self calMacWithRequestHexString:noMacIso8583Data];
}
- (void)calculateMacWithScoketMessage:(NSString *) scoketMessagHexStr
                         successBlock:(HandleResultBlock) successCB
                          failedBlock:(HandleResultBlock) failedCB
{
    if (!scoketMessagHexStr || scoketMessagHexStr.length <= 26) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"参数错误(缺少计算mac的原始数据)"];
        startCallBack(failedCB, model);
        return;
    }
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeCalcuateMac;
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [self calMacWithRequestHexString:scoketMessagHexStr];
}
#pragma mark 启动交易成功的回调 在这一步需要设置金额
-(void) onRequestSetAmount{
    //设置金额到POS
    [[QPOSService sharedInstance] setAmount:[XLPOSManager shareInstance].tradeAmount
                            aAmountDescribe:@"123"
                                   currency:@"0156"
                            transactionType:[XLPOSManager shareInstance].transactionType];
}
#pragma mark 设置金额成功，等待用户刷卡的回调
-(void) onRequestWaitingUser{
//    @"Please insert/swipe/tap card now.";
    XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_WAITTING_USER_CARD respMsg:@"请插卡/刷卡/挥卡"];
    startCallBack([XLPOSManager shareInstance].progressCB, model);
}
#pragma mark 插入芯片卡的时候的回调
-(void) onRequestTime{
    //    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    //    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    //    NSString *terminalTime = [dateFormatter stringFromDate:[NSDate date]]
    [[QPOSService sharedInstance] sendTime:[XLPOSManager shareInstance].currentTerminalTime];
}
#pragma mark 插入芯片卡的时候的回调
-(void) onRequestSelectEmvApp: (NSArray*)appList{
    if ([appList count] > 0) {
        // 需要用户选择卡类型
        if ([XLPOSManager shareInstance].progressCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_WAITTING_SELECT_CARDTYPE respMsg:@"请选择卡片类型"];
            startCallBack([XLPOSManager shareInstance].progressCB, model);
        }
        [XLPOSManager shareInstance].cardTypeArray = [appList copy];
        [[XLPOSManager shareInstance] performSelector:@selector(showCardTypeActionSheet) withObject:nil afterDelay:1.5];
    }
}
- (void)showCardTypeActionSheet{
    UIAlertController *actionsheetVC = [UIAlertController alertControllerWithTitle:@"请选择卡片类型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (int i = 0; i < [[XLPOSManager shareInstance].cardTypeArray count]; i++) {
        NSString *cardTypeName = [[XLPOSManager shareInstance].cardTypeArray[i] copy];
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:cardTypeName
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                [weakSelf selectedCardType:cardTypeName];
                                                            }];
        [actionsheetVC addAction:alertAction];
    }
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              [[QPOSService sharedInstance] cancelSelectEmvApp];
                                                          }];
    [actionsheetVC addAction:cancelAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:actionsheetVC animated:YES completion:nil];
    });
}
- (void)selectedCardType:(NSString *) cardType
{
    XLLog(@"您选择了 %@类型的卡", cardType);
    NSUInteger index = [[XLPOSManager shareInstance].cardTypeArray indexOfObject:cardType];
    [[QPOSService sharedInstance] selectEmvApp:index];
}
#pragma mark 插卡 刷卡 非接的进度提示回掉  最常用到的是提示输入密码
-(void) onRequestDisplay: (Display)displayMsg{
    NSString *msg = @"";
    if (displayMsg==Display_CLEAR_DISPLAY_MSG) {
        msg = @"";
    }else if(displayMsg==Display_PLEASE_WAIT){
        msg = @"Please wait...";
    }else if(displayMsg==Display_REMOVE_CARD){
        msg = @"Please remove card";
    }else if (displayMsg==Display_TRY_ANOTHER_INTERFACE){
        msg = @"Please try another interface";
    }else if (displayMsg == Display_TRANSACTION_TERMINATED){
        msg = @"Terminated";
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_WAITTING_TERMINATED_TYPE respMsg:msg];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
        return;
    }else if (displayMsg == Display_PIN_OK){
        msg = @"Pin ok";
    }else if (displayMsg == Display_INPUT_PIN_ING){// 最常用到
        msg = @"please input pin on pos";
        if ([XLPOSManager shareInstance].progressCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_WAITTING_INPUT_PASSWORD respMsg:msg];
            startCallBack([XLPOSManager shareInstance].progressCB, model);
        }
        return;
    }else if (displayMsg == Display_MAG_TO_ICC_TRADE){
        msg = @"please insert chip card on pos";
    }else if (displayMsg == Display_INPUT_OFFLINE_PIN_ONLY){
        msg = @"please input offline pin only";
    }else if(displayMsg == Display_CARD_REMOVED){
        msg = @"Card Removed";
    }else if (displayMsg == Display_INPUT_LAST_OFFLINE_PIN){
        msg = @"please input last offline pin";
    }
    if ([XLPOSManager shareInstance].progressCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_PROGRESS_DISPLAY respMsg:msg];
        startCallBack([XLPOSManager shareInstance].progressCB, model);
    }
}
#pragma mark 插卡 刷卡 非接回调
-(void) onDoTradeResult: (DoTradeResult)result DecodeData:(NSDictionary*)decodeData{
    NSLog(@"onDoTradeResult?>> result %ld",(long)result);
    NSString *msg = @"";
    if (result == DoTradeResult_NONE) {
        [[QPOSService sharedInstance] setFormatID:@"0008"];
        [[QPOSService sharedInstance] doTrade:30];
    }else if (result==DoTradeResult_ICC) {
        [XLPOSManager shareInstance].doTradeResult = DoTradeResult_ICC;
        msg = @"ICC Card Inserted";
        if ([XLPOSManager shareInstance].progressCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_PROGRESS_DISPLAY respMsg:msg];
            startCallBack([XLPOSManager shareInstance].progressCB, model);
        }
        [[QPOSService sharedInstance]  doEmvApp:EmvOption_START];
    }else if(result==DoTradeResult_NOT_ICC){
        msg = @"Card Inserted (Not ICC)";
        if ([XLPOSManager shareInstance].progressCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_PROGRESS_DISPLAY respMsg:msg];
            startCallBack([XLPOSManager shareInstance].progressCB, model);
        }
    }else if(result==DoTradeResult_MCR){
        [XLPOSManager shareInstance].doTradeResult = DoTradeResult_MCR;
        XLLog(@"MCR decodeData: %@",decodeData);
        XLBankCardModel *mcrModel = [[XLBankCardModel alloc] init];
        mcrModel.track2Length = [decodeData[@"track2Length"] description];
        mcrModel.track3Length = [decodeData[@"track3Length"] description];
        if ([mcrModel.track2Length integerValue] > 0) {
            mcrModel.encTrack2 = [decodeData[@"encTrack2"] substringWithRange:NSMakeRange(0, [mcrModel.track2Length integerValue])];
        }
        if ([mcrModel.track3Length integerValue] > 0) {
            mcrModel.encTrack3 = [decodeData[@"encTrack3"] substringWithRange:NSMakeRange(0, [mcrModel.track3Length integerValue])];
        }
        mcrModel.expiryDate = decodeData[@"expiryDate"];
        mcrModel.maskedPAN = decodeData[@"maskedPAN"];
        mcrModel.pinblock = decodeData[@"pinblock"];
        mcrModel.serviceCode = decodeData[@"serviceCode"];
        // 待区分消费和消费撤销
        [self fillISO8583ParamsWithBankCardModel:mcrModel];
        
    }else if(result==DoTradeResult_NFC_OFFLINE || result == DoTradeResult_NFC_ONLINE){
        [XLPOSManager shareInstance].doTradeResult = DoTradeResult_NFC_ONLINE;
        NSDictionary *getIcctag = [[QPOSService sharedInstance] getICCTag:1 tagCount:3 tagArrStr:@"9F0D9F0E9F0F"];
        NSLog(@"--------getIcctag:%@",getIcctag);
        NSLog(@"decodeData: %@",decodeData);
//        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
//        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
//        NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",decodeData[@"expiryDate"]];
//        NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",decodeData[@"cardholderName"]];
//        //NSString *ksn = [NSString stringWithFormat:@"KSN: %@\n",decodeData[@"ksn"]];
//        NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",decodeData[@"serviceCode"]];
//        //NSString *track1Length = [NSString stringWithFormat:@"Track 1 Length: %@\n",decodeData[@"track1Length"]];
//        //NSString *track2Length = [NSString stringWithFormat:@"Track 2 Length: %@\n",decodeData[@"track2Length"]];
//        //NSString *track3Length = [NSString stringWithFormat:@"Track 3 Length: %@\n",decodeData[@"track3Length"]];
//        //NSString *encTracks = [NSString stringWithFormat:@"Encrypted Tracks: %@\n",decodeData[@"encTracks"]];
//        NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",decodeData[@"encTrack1"]];
//        NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",decodeData[@"encTrack2"]];
//        NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",decodeData[@"encTrack3"]];
//        //NSString *partialTrack = [NSString stringWithFormat:@"Partial Track: %@",decodeData[@"partialTrack"]];
//        NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",decodeData[@"pinKsn"]];
//        NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",decodeData[@"trackksn"]];
//        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinblock"]];
//        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
//
//        NSString *msg = [NSString stringWithFormat:@"Tap Card:\n"];
//        msg = [msg stringByAppendingString:formatID];
//        msg = [msg stringByAppendingString:maskedPAN];
//        msg = [msg stringByAppendingString:expiryDate];
//        msg = [msg stringByAppendingString:cardHolderName];
//        msg = [msg stringByAppendingString:pinKsn];
//        msg = [msg stringByAppendingString:trackksn];
//        msg = [msg stringByAppendingString:serviceCode];
//
//        msg = [msg stringByAppendingString:encTrack1];
//        msg = [msg stringByAppendingString:encTrack2];
//        msg = [msg stringByAppendingString:encTrack3];
//        msg = [msg stringByAppendingString:pinBlock];
//        msg = [msg stringByAppendingString:encPAN];
        
        dispatch_async(dispatch_get_main_queue(),  ^{
            NSDictionary *mDic = [[QPOSService sharedInstance] getNFCBatchData];
            NSString *tlv;
            NSString *iccdata;
            if(mDic !=nil){
                tlv= [NSString stringWithFormat:@"%@",mDic[@"tlv"]];
                XLLog(@"tlv = %@", tlv);
                NSDictionary *info = [DecryptTLV decryptTLVToDict:tlv];
                NSString *C0 = [info objectForKey:@"C0"];
                NSString *C2 = [info objectForKey:@"C2"];
                
                if (C0.length != 0 && C2.length != 0) {
                    iccdata = [DUKPT_2009_CBC decryptionTrackDataCBC:C0 BDK:@"0123456789ABCDEFFEDCBA9876543210" data:C2];
                    NSDictionary *iccdataDict = [DecryptTLV decryptTLVToDict:iccdata];
                    BerTlvBuilder *builder = [[BerTlvBuilder alloc] init];
                    for (int m = 0; m < [[XLPOSManager shareInstance].tagsArray count]; m++) {
                        NSString *key = [XLPOSManager shareInstance].tagsArray[m];
                        NSString *value = [iccdataDict valueForKey:key];
                        [builder addHex:value tag:[BerTag parse:key]];
                    }
                    NSError *dataError;
                    NSData *expectedData = [builder buildDataWithError:&dataError];
                    iccdata = [HexUtil format:expectedData];
                    XLLog(@"iccdata = %@", iccdata);
                    NSLog(@"%@", iccdata);
                }else{
                    if ([XLPOSManager shareInstance].failedCB) {
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_NFC_READ_ERROR respMsg:@""];
                        startCallBack([XLPOSManager shareInstance].failedCB, model);
                        return;
                    }
                }
            }else{
                //nfc 交易没有缺iccdata
                if ([XLPOSManager shareInstance].failedCB) {
                    XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_NFC_READ_ERROR respMsg:@""];
                    startCallBack([XLPOSManager shareInstance].failedCB, model);
                    return;
                }
            }
            NSLog(@"NFC decodeData = %@",decodeData);
            XLBankCardModel *iccModel = [[XLBankCardModel alloc] init];
            iccModel.track2Length = [decodeData[@"track2Length"] description];
            iccModel.track3Length = [decodeData[@"track3Length"] description];
            if ([iccModel.track2Length integerValue] > 0) {
                iccModel.encTrack2 = [decodeData[@"encTrack2"] substringWithRange:NSMakeRange(0, [iccModel.track2Length integerValue])];
            }
            if ([iccModel.track3Length integerValue] > 0) {
                iccModel.encTrack3 = [decodeData[@"encTrack3"] substringWithRange:NSMakeRange(0, [iccModel.track3Length integerValue])];
            }
            if ([decodeData[@"expiryDate"] description].length > 4) {
                iccModel.expiryDate = [[decodeData[@"expiryDate"] description] substringWithRange:NSMakeRange(0, 4)];
            }else{
                iccModel.expiryDate = [decodeData[@"expiryDate"] description];
            }
            
            iccModel.maskedPAN = decodeData[@"maskedPAN"];
            iccModel.pinblock = decodeData[@"pinblock"];
            iccModel.serviceCode = decodeData[@"serviceCode"];
            iccModel.iccdata = iccdata;
            iccModel.cardSquNo = decodeData[@"cardSquNo"];
            [[XLPOSManager shareInstance] fillISO8583ParamsWithBankCardModel:iccModel];
        });
        
    }else if(result==DoTradeResult_NFC_DECLINED){
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_NFC_READ_ERROR respMsg:@"Tap Card Declined"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
    }else if (result==DoTradeResult_NO_RESPONSE){
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_NFC_READ_ERROR respMsg:@"Check card no response"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
    }else if(result==DoTradeResult_BAD_SWIPE){
//        self.textViewLog.text = @"Bad Swipe. \nPlease swipe again and press check card.";
        
        //        [pos doTrade:30];
    }else if(result==DoTradeResult_NO_UPDATE_WORK_KEY){
//        self.textViewLog.text = @"Device not update work key";
    }
}
-(void) onRequestOnlineProcess: (NSString*) tlv{
    @try {
        NSDictionary *dict = [DecryptTLV decryptTLVToDict:tlv];
        NSString *C0 = [dict objectForKey:@"C0"];
        NSString *C2 = [dict objectForKey:@"C2"];
        
        if (C0.length != 0 && C2.length != 0) {
            NSString *c2Data = [DUKPT_2009_CBC decryptionTrackDataCBC:C0 BDK:@"0123456789ABCDEFFEDCBA9876543210" data:C2];
            NSDictionary *c2DataTLV = [DecryptTLV decryptTLVToDict:c2Data];
            NSString *cardNumStr = [c2DataTLV objectForKey:@"5A"];
            if ([cardNumStr containsString:@"F"]) {
                cardNumStr = [cardNumStr substringToIndex:cardNumStr.length-1];
            }
            
            NSString *c1 = [dict objectForKey:@"C1"];//pin ksn
            NSString *c7 = [dict objectForKey:@"C7"];//pinblock
            if (c1.length != 0 && c7.length != 0) {
                NSString *pinblockStr = [DUKPT_2009_CBC decryptionPinblock:c1 BDK:@"0123456789ABCDEFFEDCBA9876543210" data:c7 andCardNum:cardNumStr];
                NSLog(@"pinBlock = %@", pinblockStr);
            }
        }else{
            // ic 卡返回数据
            NSDictionary *decodeData = [[QPOSService sharedInstance] anlysEmvIccData:tlv];
            NSLog(@"onRequestOnlineProcess = %@",decodeData);
            XLBankCardModel *iccModel = [[XLBankCardModel alloc] init];
            iccModel.track2Length = [decodeData[@"track2Length"] description];
            iccModel.track3Length = [decodeData[@"track3Length"] description];
            if ([iccModel.track2Length integerValue] > 0) {
                iccModel.encTrack2 = [decodeData[@"encTrack2"] substringWithRange:NSMakeRange(0, [iccModel.track2Length integerValue])];
            }
            if ([iccModel.track3Length integerValue] > 0) {
                iccModel.encTrack3 = [decodeData[@"encTrack3"] substringWithRange:NSMakeRange(0, [iccModel.track3Length integerValue])];
            }
            if ([decodeData[@"expiryDate"] description].length > 4) {
                iccModel.expiryDate = [[decodeData[@"expiryDate"] description] substringWithRange:NSMakeRange(0, 4)];
            }else{
                iccModel.expiryDate = [decodeData[@"expiryDate"] description];
            }
            
            iccModel.maskedPAN = decodeData[@"maskedPAN"];
            iccModel.pinblock = decodeData[@"pinblock"];
            iccModel.serviceCode = decodeData[@"serviceCode"];
            iccModel.iccdata = decodeData[@"iccdata"];
            iccModel.cardSquNo = decodeData[@"cardSquNo"];
            [[XLPOSManager shareInstance] fillISO8583ParamsWithBankCardModel:iccModel];
        }
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
    
    
}

-(void) onRequestTransactionResult: (TransactionResult)transactionResult{
    
    NSString *message = @"";
    if (transactionResult==TransactionResult_APPROVED) {
        NSString *message = [NSString stringWithFormat:@"Approved\nAmount: $%@\n",[XLPOSManager shareInstance].tradeAmount];
        message = message;
    }else if(transactionResult == TransactionResult_TERMINATED) {
        message = @"Terminated";
    } else if(transactionResult == TransactionResult_DECLINED) {
        message = @"Declined";
    } else if(transactionResult == TransactionResult_CANCEL) {
        message = @"Cancel";
    } else if(transactionResult == TransactionResult_CAPK_FAIL) {
        message = @"Fail (CAPK fail)";
    } else if(transactionResult == TransactionResult_NOT_ICC) {
        message = @"Fail (Not ICC card)";
    } else if(transactionResult == TransactionResult_SELECT_APP_FAIL) {
        message = @"Fail (App fail)";
    } else if(transactionResult == TransactionResult_DEVICE_ERROR) {
        message = @"Pos Error";
    } else if(transactionResult == TransactionResult_CARD_NOT_SUPPORTED) {
        message = @"Card not support";
    } else if(transactionResult == TransactionResult_MISSING_MANDATORY_DATA) {
        message = @"Missing mandatory data";
    } else if(transactionResult == TransactionResult_CARD_BLOCKED_OR_NO_EMV_APPS) {
        message = @"Card blocked or no EMV apps";
    } else if(transactionResult == TransactionResult_INVALID_ICC_DATA) {
        message = @"Invalid ICC data";
    }else if(transactionResult == TransactionResult_NFC_TERMINATED) {
        message = @"NFC Terminated";
    }
    XLLog(message);
//    [[QPOSService sharedInstance] resetPosStatus];
    if ([XLPOSManager shareInstance].failedCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_ERROR respMsg:message];
        startCallBack([XLPOSManager shareInstance].failedCB, model);
    }
}
#pragma mark - 计算mac
- (void)calMacWithRequestHexString:(NSString *) hexString
{
    NSData *aa =  [Util ecb:[Util HexStringToByteArray:hexString]];
    [[QPOSService sharedInstance] calcMacSingle_all:[Util byteArray2Hex:aa] delay:5];
}
-(void)onRequestCalculateMac:(NSString *)calMacString
{
    XLLog(@"计算mac结果 = %@", calMacString);
    if (calMacString && calMacString.length == 16) {
        if ([XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeConsume ||
            [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeConsumeCancel ||
            [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeConsumeReverse ||
            [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeConsumeCancelReverse||
            [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeCalcuateMac ||
            [XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeReturnGoods) {
            NSString *macHead8 = [calMacString substringWithRange:NSMakeRange(0, 8)];
            NSData *macData = [macHead8 dataUsingEncoding:NSUTF8StringEncoding];
            NSString *macHex = [TransformNSString hexStringFromData:macData];
            XLPackModel *model = [XLPOSManager shareInstance].mrcPackModel;
            NSString *tempStr = [model.ISO8583HexStr substringWithRange:NSMakeRange(0, model.ISO8583HexStr.length - 16)];
            
            model.ISO8583HexStr = [tempStr stringByAppendingString:macHex];
            model.socketAllHexStr = [model.headHexStr stringByAppendingString:tempStr];
            model.socketAllHexStr = [model.socketAllHexStr stringByAppendingString:macHex];
            XLResponseModel *respModel = [XLResponseModel createWithPackModel:model respMsgWithCode:RESP_SUCCESS respMsg:@"封包成功"];
            respModel.data = [XLPOSManager shareInstance].iso8583FieldsParams;
            [XLPOSManager shareInstance].successCB(respModel);
        }else if([XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeCheckMac){
            NSString *macHead8 = [calMacString substringWithRange:NSMakeRange(0, 8)];
            NSData *macData = [macHead8 dataUsingEncoding:NSUTF8StringEncoding];
            NSString *macHex = [TransformNSString hexStringFromData:macData];
            if ([macHex isEqualToString:[XLPOSManager shareInstance].capRespMacHexStr]) {
                XLLog(@"CAP返回的MAC和POS计算的MAC相同");
                XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"CAP返回MAC校验成功"];
                startCallBack([XLPOSManager shareInstance].successCB, model);
            }else{
                XLLog(@"CAP返回的MAC和POS计算的MAC不同");
                XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"CAP返回MAC校验失败(请重新设置主密钥和工作密钥)"];
                startCallBack([XLPOSManager shareInstance].failedCB, model);
            }
        }else if([XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeHandleScript){
            NSString *macHead8 = [calMacString substringWithRange:NSMakeRange(0, 8)];
            NSData *macData = [macHead8 dataUsingEncoding:NSUTF8StringEncoding];
            NSString *macHex = [TransformNSString hexStringFromData:macData];
            XLPackModel *model = [XLPOSManager shareInstance].mrcPackModel;
            NSString *tempStr = [model.ISO8583HexStr substringWithRange:NSMakeRange(0, model.ISO8583HexStr.length - 16)];
            
            model.ISO8583HexStr = [tempStr stringByAppendingString:macHex];
            model.socketAllHexStr = [model.headHexStr stringByAppendingString:tempStr];
            model.socketAllHexStr = [model.socketAllHexStr stringByAppendingString:macHex];
            
            // 这个地方需要直接发送脚本了，需要在下载交易连接上送脚本通知
            // 这个地方需要把上次交易的脚本存储起来，下一次发送
            NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
            [userDefault setValue:model.socketAllHexStr forKey:@"LAST_SCRIPT_NOTIFICATION"];
            [userDefault synchronize];
            XLLog(@"脚本通知的报文已存储");
        }else{
            
        }
    }else{
        XLLog(@"MAC计算错误");
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_CALCUATE_MAC_ERROR respMsg:@"MAC计算错误"];
        if ([XLPOSManager shareInstance].failedCB) {
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
    }
    
}
#pragma mark - POS交易过程中发生错误
-(void) onDHError: (DHError)errorState{
    NSString *msg = @"";
    if(errorState ==DHError_TIMEOUT) {
        msg = @"Pos no response";
    } else if(errorState == DHError_DEVICE_RESET) {
        msg = @"Pos reset";
    } else if(errorState == DHError_UNKNOWN) {
        msg = @"Unknown error";
    } else if(errorState == DHError_DEVICE_BUSY) {
        msg = @"Pos Busy";
    } else if(errorState == DHError_INPUT_OUT_OF_RANGE) {
        msg = @"Input out of range.";
    } else if(errorState == DHError_INPUT_INVALID_FORMAT) {
        msg = @"Input invalid format.";
    } else if(errorState == DHError_INPUT_ZERO_VALUES) {
        msg = @"Input are zero values.";
    } else if(errorState == DHError_INPUT_INVALID) {
        msg = @"Input invalid.";
    } else if(errorState == DHError_CASHBACK_NOT_SUPPORTED) {
        msg = @"Cashback not supported.";
    } else if(errorState == DHError_CRC_ERROR) {
        msg = @"CRC Error.";
    } else if(errorState == DHError_COMM_ERROR) {
        msg = @"Communication Error.";
    }else if(errorState == DHError_MAC_ERROR){
        msg = @"MAC Error.";
    }else if(errorState == DHError_CMD_TIMEOUT){ // 命令超时的回调
        msg = @"CMD Timeout.";
    }else if(errorState == DHError_AMOUNT_OUT_OF_LIMIT){
        msg = @"Amount out of limit.";
    }
    [[QPOSService sharedInstance] resetPosStatus];
    XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_ERROR respMsg:msg];
    if ([XLPOSManager shareInstance].failedCB) {
        startCallBack([XLPOSManager shareInstance].failedCB, model);
        [XLPOSManager shareInstance].failedCB = nil;
    }
}

#pragma mark - 封包
#pragma mark 磁条卡封包
- (void)fillISO8583ParamsWithBankCardModel:(XLBankCardModel *) mcrModel
{
    // 区分POS交易逻辑 消费 消费撤销 消费冲正 消费撤销冲正
    if ([XLPOSManager shareInstance].posTradeType == XLPayBusinessTypeReturnGoods) {
        [[XLPOSManager shareInstance] doReturnGoodsFillISO8583ParamsWithModel: mcrModel];
        return;
    }
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *terminalId = [userDefaults valueForKey:kTERMINALID_USERDEFAULT_KEY];
    NSString *merchatId = [userDefaults valueForKey:kMERCHANTID_USERDEFAULT_KEY];
    if (!terminalId || !merchatId) {
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
        return;
    }
    NSDictionary *fixedParam = @{
                                 @"0": @"0200",
                                 @"3": @"000000",
                                 @"25":  @"00",
                                 @"41":  terminalId,
                                 @"42":  merchatId,
                                 @"47":  @"5049303537030550333039390402303205103030303030323032334B31333937343306063030303031390708334633443033383408083932313020202020",
                                 @"49":  [[XLConfigManager share] getCurrency],
                                 @"57": @"32313843323532303420202020202020202020",
                                 @"64": @"FFFFFFFFFFFFFFFF"
                                 };
    [paramDict setDictionary:fixedParam];
    NSString *field4 = @"000000000000";
    NSUInteger amountLen = [XLPOSManager shareInstance].tradeAmount.length;
    field4 = [field4 stringByReplacingCharactersInRange:NSMakeRange(field4.length - amountLen, amountLen) withString:[XLPOSManager shareInstance].tradeAmount];
    [paramDict setObject:field4 forKey:@"4"];
    [paramDict setObject:[XLPOSManager shareInstance].tradeNumber forKey:@"11"];
    
    if (mcrModel.expiryDate && mcrModel.expiryDate.length > 0) {
//        [paramDict setValue:@"4912" forKey:@"14"];
        [paramDict setValue:mcrModel.expiryDate forKey:@"14"];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"缺少卡有效期"];
        startCallBack([XLPOSManager shareInstance].failedCB, model);
        return;
    }
    
    // 二磁明文数据
    if ([mcrModel.track2Length integerValue] > 0) {
//        NSString *track2 = [mcrModel.encTrack2 stringByReplacingOccurrencesOfString:@"F" withString:@""];
        [paramDict setValue:mcrModel.encTrack2  forKey:@"35"];
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_LACK_TRACK2_ERROR respMsg:@"缺少二磁数据"];
        startCallBack([XLPOSManager shareInstance].failedCB, model);
        return;
    }
    // 三磁明文数据 有就传
    if ([mcrModel.track3Length integerValue] > 0) {
        [paramDict setValue:mcrModel.encTrack3 forKey:@"36"];
    }
    // 免密交易 和 密码交易 如果有卡密返回就是走密码交易，如果没有密码返回就走免密交易
    // @"60": @"2201024900050", 最后一位表示免密，以前传13位，默认补位
    NSString *readCardAbility = @"6";
    if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
        readCardAbility = @"6";
    }else{
        readCardAbility = @"5";
    }
    if (mcrModel.pinblock && mcrModel.pinblock.length > 0) {
        [paramDict setValue:@"021" forKey:@"22"]; //刷卡，且pin可输入
        NSString *field60 = [NSString stringWithFormat:@"22%@000%@01", [XLPOSManager shareInstance].batchId, readCardAbility];
        [paramDict setValue:field60 forKey:@"60"];
        // 密码交易需要传递卡密
        [paramDict setValue:mcrModel.pinblock forKey:@"52"];
        [paramDict setValue:@"2600000000000000" forKey:@"53"];//带主账号信息 双倍长密钥 磁道不加密
    }else{
        [paramDict setValue:@"022" forKey:@"22"]; //刷卡，无pin
        NSString *field60 = [NSString stringWithFormat:@"22%@000%@00", [XLPOSManager shareInstance].batchId, readCardAbility];
        [paramDict setValue:field60 forKey:@"60"];
    }
    // IC卡交易相关
    if (mcrModel.iccdata && mcrModel.iccdata.length > 0) {
        //IC卡交易 重新设置22域数据
        if (mcrModel.pinblock && mcrModel.pinblock.length > 0) {
            if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
                [paramDict setValue:@"071" forKey:@"22"];
            }else{
                [paramDict setValue:@"051" forKey:@"22"];
            }
        }else{
            if ([XLPOSManager shareInstance].doTradeResult == DoTradeResult_NFC_ONLINE) {
                [paramDict setValue:@"072" forKey:@"22"];
            }else{
                [paramDict setValue:@"050" forKey:@"22"];
            }
        }
        [paramDict setValue:@"001" forKey:@"23"];
        [paramDict setValue:mcrModel.iccdata forKey:@"55"];
    }
    // 区分交易类型
    switch ([XLPOSManager shareInstance].posTradeType) {
        case XLPayBusinessTypeConsume:
        {
            
        }
            break;
        case XLPayBusinessTypeConsumeCancel:
        {
            [paramDict setValue:@"200000" forKey:@"3"];
            [paramDict setValue:[XLPOSManager shareInstance].capQueryNumber forKey:@"37"];
            NSString *field60 = [paramDict valueForKey:@"60"];
            field60 = [field60 stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@"23"];
            [paramDict setValue:field60 forKey:@"60"];
            NSString *field61 = [NSString stringWithFormat:@"%@%@", [XLPOSManager shareInstance].originBatchId, [XLPOSManager shareInstance].originTradeNumber];
            [paramDict setValue:field61 forKey:@"61"];
        }
            break;
        case XLPayBusinessTypeConsumeReverse:
        {
            
        }
            break;
        case XLPayBusinessTypeConsumeCancelReverse:
        {
            
        }
            break;
        default:
            break;
    }
    [XLPOSManager shareInstance].iso8583FieldsParams = paramDict; //记录消费和消费撤销的iso报文参数
    
    XLLog(@"ISO fileds params = %@", paramDict);
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:paramDict completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [self calMacWithRequestHexString:tempStr];
        }else{
            if ([XLPOSManager shareInstance].failedCB) {
                startCallBack([XLPOSManager shareInstance].failedCB, respModel);
                [XLPOSManager shareInstance].failedCB = nil;
            }
        }
    }];
}
#pragma makr - IC卡回写ICCData
/**
 *    @brief    回写iccdata
 *    @param    tradeSuccess 是否交易成功
 *    @param    originTradeParams 原始交易数据
 *    @param    originCapRespParams 原始交易数据上送CAP返回的数据
 *    @param    iccdata   iccdata
 *    @param    successCB    成功回调
 *    @param    failedCB     失败回调
 */
- (void)sendOnlineProcessResult:(BOOL) tradeSuccess
              originTradeParams:(NSDictionary *) originTradeParams
            originCapRespParams:(NSDictionary *) originCapRespParams
                        iccdata:(NSString *) iccdata
                   successBlock:(HandleResultBlock) successCB
                    failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    
    if (!originTradeParams[@"22"] ||
        !originTradeParams[@"35"]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"原始交易数据错误，请重试"];
        startCallBack(failedCB, model);
        return;
    }
    if (!originCapRespParams[@"4"] ||
        !originCapRespParams[@"11"] ||
        !originCapRespParams[@"13"] ||
        !originCapRespParams[@"32"] ||
        !originCapRespParams[@"37"] ||
        !originCapRespParams[@"60"]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"CAP返回的应答数据错误，请重试"];
        startCallBack(failedCB, model);
        return;
    }
    
    [XLPOSManager shareInstance].successCB = [successCB copy];
    [XLPOSManager shareInstance].progressCB = nil;
    [XLPOSManager shareInstance].failedCB = [failedCB copy];
    [XLPOSManager shareInstance].originTradeParams = originTradeParams;
    [XLPOSManager shareInstance].originCapRespParams = originCapRespParams;
    
    NSString *codeStr = tradeSuccess ? @"8A023030" : @"8A023035";
    NSString *sendResult = ((iccdata == nil) ? codeStr : [NSString stringWithFormat:@"%@%@", codeStr, iccdata]);
    [[QPOSService sharedInstance] sendOnlineProcessResult:sendResult];
}
- (void) onReturnReversalData: (NSString*)tlv{
    XLLog(@"onReversalData %@",tlv);
    //联机交易拒绝
    if (tlv && tlv.length > 0) {
        @try {
            [[XLPOSManager shareInstance] handleScriptNotificationMessageWithTLV:tlv];
        } @catch (NSException *exception) {
            XLLog(@"exception = %@", [exception description]);
            [[QPOSService sharedInstance] resetPosStatus];
        } @finally {
            [[QPOSService sharedInstance] closeDevice];
        }
    }
    if ([XLPOSManager shareInstance].failedCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_ONLINE_TRANSACTION_REJECT respMsg:@"联机交易拒绝"];
        startCallBack([XLPOSManager shareInstance].failedCB, model);
    }
}
-(void) onRequestTransactionLog: (NSString*)tlv{
    XLLog(@"onTransactionLog %@",tlv);
}
-(void) onRequestBatchData: (NSString*)tlv{
    XLLog(@"onBatchData %@",tlv);

    if (tlv && tlv.length > 0) {
        @try {
            [[XLPOSManager shareInstance] handleScriptNotificationMessageWithTLV:tlv];
        } @catch (NSException *exception) {
            XLLog(@"exception = %@", [exception description]);
            if ([XLPOSManager shareInstance].failedCB) {
                XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_EXCEPTIOM respMsg:@"POS异常，请稍后重试"];
                startCallBack([XLPOSManager shareInstance].failedCB, model);
            }
            [[QPOSService sharedInstance] resetPosStatus];
            [[QPOSService sharedInstance] closeDevice];
        } @finally {
            
        }
    }
    if ([XLPOSManager shareInstance].successCB) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"联机交易成功"];
        startCallBack([XLPOSManager shareInstance].successCB, model);
    }
}
- (void)handleScriptNotificationMessageWithTLV:(NSString *) tlv{
    [XLPOSManager shareInstance].posTradeType = XLPayBusinessTypeHandleScript;
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *terminalId = [userDefaults valueForKey:kTERMINALID_USERDEFAULT_KEY];
    NSString *merchatId = [userDefaults valueForKey:kMERCHANTID_USERDEFAULT_KEY];
    if (!terminalId || !merchatId) {
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
        return;
    }
    @try {
        NSDictionary *fixedParam = @{
                                     @"0": @"0620",
                                     @"3": @"000000",
                                     @"41":  terminalId,
                                     @"42":  merchatId,
                                     @"49":  [[XLConfigManager share] getCurrency],
                                     @"64": @"FFFFFFFFFFFFFFFF"
                                     };
        [paramDict setDictionary:fixedParam];
        [paramDict setObject:[XLPOSManager shareInstance].originCapRespParams[@"4"] forKey:@"4"];
        [paramDict setObject:[XLPOSManager shareInstance].originCapRespParams[@"11"] forKey:@"11"];
        [paramDict setObject:[XLPOSManager shareInstance].originTradeParams[@"22"] forKey:@"22"];
        [paramDict setObject:[XLPOSManager shareInstance].originCapRespParams[@"32"] forKey:@"32"];
        [paramDict setObject:[XLPOSManager shareInstance].originCapRespParams[@"37"] forKey:@"37"];
        [paramDict setObject:tlv forKey:@"55"];
        // 二磁明文数据
        if ([XLPOSManager shareInstance].originTradeParams[@"35"]) {
            [paramDict setValue:[XLPOSManager shareInstance].originTradeParams[@"35"]forKey:@"35"];
        }
        // 三磁明文数据 有就传
        if ([XLPOSManager shareInstance].originTradeParams[@"36"]) {
            [paramDict setValue:[XLPOSManager shareInstance].originTradeParams[@"36"] forKey:@"36"];
        }
        // 60域原交易数据需处理
        // 22010249000500
        NSString *originField60 = [[XLPOSManager shareInstance].originCapRespParams[@"60"] description];
        NSString *tailStr = [originField60 substringWithRange:NSMakeRange(11, originField60.length - 11)];
        NSString *originBatchNum = [originField60 substringWithRange:NSMakeRange(2, 6)];
        NSString *field60 = [NSString stringWithFormat:@"00%@951%@", originBatchNum, tailStr];
        [paramDict setObject:field60 forKey:@"60"];
        NSString *originClientNum = [XLPOSManager shareInstance].originCapRespParams[@"11"];
        NSString *originTradeDate = [XLPOSManager shareInstance].originCapRespParams[@"13"];
        NSString *field61 = [NSString stringWithFormat:@"%@%@%@", originBatchNum, originClientNum, originTradeDate];
        [paramDict setObject:field61 forKey:@"61"];
        XLLog(@"上送脚本原始数据 %@", paramDict);
        [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:paramDict completion:^(XLResponseModel *respModel) {
            XLPackModel *packModel = [[XLPackModel alloc] init];
            packModel.headHexStr = respModel.data[@"msg_head_data"];
            packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
            packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
            [XLPOSManager shareInstance].mrcPackModel = packModel;
            XLLog(@"封包结果 = %@", respModel.data);
            if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
                NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
                [self calMacWithRequestHexString:tempStr];
            }
        }];
    } @catch (NSException *exception) {
        if ([XLPOSManager shareInstance].failedCB) {
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_POS_EXCEPTIOM respMsg:@"POS异常，请稍后重试"];
            startCallBack([XLPOSManager shareInstance].failedCB, model);
        }
        [[QPOSService sharedInstance] resetPosStatus];
        [[QPOSService sharedInstance] closeDevice];
    } @finally {
        
    }
}

@end
