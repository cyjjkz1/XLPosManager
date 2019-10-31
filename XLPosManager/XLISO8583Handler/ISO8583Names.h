//
//  ISO8583Names.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/3.
//  Copyright © 2019年 ccd. All rights reserved.
//

#ifndef ISO8583Names_h
#define ISO8583Names_h
/* 000 */#define MSG_TYPE_INDETIFIER                @"0" //消息类型
/* 001 */#define BITMAP_EXTEND                      @"1" //扩展域 为1的时候位图为128
/* 002 */#define PRIMARY_ACCOUNT_NUMBER             @"2" //主账号
/* 003 */#define PROCESSING_CODE                    @"3" //交易处理码
/* 004 */#define AMOUNT_OF_TRANSACTIONS             @"4" //交易金额
/* 005 */#define SETTLEMENT_AMOUNT                  @"5"
/* 006 */#define AMOUNT_OF_CARDHOLDER_BILLING       @"6" //持卡人扣账金额

/* 007 */#define DATE_AND_TIME_TRANSMISSION         @"7" //
/* 008 */#define Cardholder_billing_fee_Amount      @"8"
/* 009 */#define CONVERSION_RATE_RECONCILIATION     @"9"
/* 010 */#define CONVERSION_RATE_CARDHOLDER_BILLING @"10" //持卡人扣账汇率
/* 011 */#define SYSTEMS_TRACE_AUDIT_NUMBER         @"11" //受卡方系统跟踪号
/* 012 */#define TIME_OF_LOCAL_TRANSACTION          @"12" //受卡方所在地时间
/* 013 */#define DATE_OF_LOCAL_TRANSACTION          @"13" //受卡方所在地日期
/* 014 */#define DATE_OF_EXPIRED                    @"14" //卡有效期
/* 015 */#define DATE_OF_SETTLEMENT                 @"15" //清算日期
/* 016 */#define DATE_CONVERSION                    @"16"
/* 017 */#define DATE_CAPTURE                       @"17"
/* 018 */#define MERCHANT_TYPE                      @"18"

/* 019 */#define COUNTRY_CODE_ACQUIRING_INSTITUTION          @"19"
/* 020 */#define COUNTRY_CODE_PRIMARY_ACCOUNT_NUMBER         @"20"
/* 021 */#define COUNTRY_CODE_FORWARDING_INSTITUTION         @"21"
/* 022 */#define POINT_OF_SERVICE_ENTRY_MODE                 @"22" //服务点输入方式码
/* 023 */#define CARD_SEQUENCE_NUMBER                        @"23" //卡序列号
/* 024 */#define NETWORK_INTERNATIONAL_ID                    @"24" //
/* 025 */#define POINT_OF_SERVICE_CONDITION_MODE             @"25" //服务点条件码
/* 026 */#define POINT_OF_SERVICE_PIN_CAPTURE_CODE           @"26" //服务点PIN获取码
/* 027 */#define AUTHORIZATION_IDENTIFICATION_RESP_LEN       @"27" //
/* 028 */#define AMOUNT_TRANSACTION_FEE                      @"28"
/* 029 */#define AMOUNT_SETTLEMENT_FEE                       @"29"
/* 030 */#define AMOUNT_TRANSACTION_PROCESSING_FEE           @"30"

/* 031 */#define AMOUNT_SETTLEMENT_PROCESSING_FEE            @"31"
/* 032 */#define ACQUIRER_INSTITUTION_IDENTIFICATION_CODE    @"32" //受理方标识码
/* 033 */#define FORWARDING_INSTITUTION_IDENT_CODE           @"33"
/* 034 */#define PAN_EXTENDED                                @"34"
/* 035 */#define TRACK_2_DATA                                @"35" //2磁道数据
/* 036 */#define TRACK_3_DATA                                @"36" //3磁道数据
/* 037 */#define RETRIEVAL_REFERENCE_NUMBER                  @"37" //检索参考号
/* 038 */#define AUTHORIZATION_IDENTIFICATION_RESPONSE_CODE  @"38" //授权标识应答码
/* 039 */#define RESPONSE_CODE                               @"39" //应答码
/* 040 */#define SERVICE_RESTRICTION_CODE                    @"40"

/* 041 */#define CARD_ACCEPTOR_TERMINAL_IDENTIFICATION       @"41" //受卡机终端标识码
/* 042 */#define CARD_ACCEPTOR_IDENTIFICATION_CODE           @"42" //受卡方标识码
/* 043 */#define CARD_ACCEPTOR_NAME_LOCATION                 @"43" //
/* 044 */#define ADDITIONAL_RESPONSE_DATA                    @"44" //附加响应数据
/* 045 */#define TRACK_1_DATA                                @"45"
/* 046 */#define CUSTOM_DATA_ISO_46                          @"46" //自定义域
/* 047 */#define CUSTOM_DATA_ISO_47                          @"47" //自定义域
/* 048 */#define ADITIONAL_DATA_PRIVATE                      @"48" //附加数据 私有
/* 049 */#define CURRENCY_CODE_OF_TRANSACTION                @"49" //交易货币代码
/* 050 */#define CURRENCY_CODE_SETTLEMENT                    @"50"

/* 051 */#define CURRENCY_CODE_OF_CARDHOLDER_BILLING         @"51" //持卡人扣帐货币代码
/* 052 */#define PIN_DATA                                    @"52" //个人标识码数据
/* 053 */#define SECURITY_RELATED_CTRL_INFORMATION           @"53" //安全控制信息
/* 054 */#define BALANCE_AMOUNT                              @"54" //附加金额
/* 055 */#define INTERGRATED_CIRCUIT_CARD_SYSTEM_RELATED_DATA     @"55" //IC卡数据域
/* 056 */#define RESERVED_ISO_1                              @"56"
/* 057 */#define ADDITIONAL_TRANSACTION_INFORMATION          @"57" //附加交易信息
/* 058 */#define RESERVED_NATIONAL_1                         @"58"
/* 059 */#define RESERVED_PRIVATE_59                         @"59" //自定义域
/* 060 */#define RESERVED_PRIVATE_60                         @"60" //自定义域

/* 061 */#define ORIGINAL_MESSAGE                            @"61" //原始信息域
/* 062 */#define RESERVED_PRIVATE_62                         @"62" //自定义域
/* 063 */#define RESERVED_PRIVATE_63                         @"63" //自定义域
/* 064 */#define MESSAGE_AUTHENTICATION_CODE                 @"64" //报文鉴别码

#endif /* ISO8583Names_h */
