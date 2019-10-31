//
//  XLResponsePackModel.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/4.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLResponseModel.h"
#import "XLAuthPublicModel.h"

@implementation XLResponseModel
+ (XLResponseModel *)createRespMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg respData:(NSDictionary *)dataDict
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    model.data = dataDict;
    return model;
}
+ (XLResponseModel *)createRespMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    return model;
}
+ (XLResponseModel *)createWithMasterKeyModel:(XLTMKModel *)tmkModel respMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    model.tmkModel = tmkModel;
    return model;
}
+ (XLResponseModel *)createWithWorkKeyModel:(XLWorkKeyModel *)workKeyModel respMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    model.workKeyModel = workKeyModel;
    return model;
}
+ (XLResponseModel *)createWithMagneticCardModel:(XLBankCardModel *) bankCardModel respMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    model.bankCardModel = bankCardModel;
    return model;
}
+ (XLResponseModel *)createWithPackModel:(XLPackModel *) packModel respMsgWithCode:(NSString *)respCode respMsg:(NSString *)respMsg
{
    XLResponseModel *model = [[XLResponseModel alloc] init];
    model.respCode = respCode;
    model.respMsg = respMsg;
    model.packModel = packModel;
    return model;
}
@end

void startCallBack(HandleResultBlock cbBlock, XLResponseModel *model)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        cbBlock(model);
    });
}
