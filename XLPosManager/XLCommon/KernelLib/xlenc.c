#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <openssl/aes.h>
#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/des.h>
#include <openssl/evp.h>
#include "xlenc.h"
#include "bcd.h"


/** openssl的初始化
 *
 */
void qfsdk_init() {
	//LOGW("in generate_key ");
	OpenSSL_add_all_algorithms();
	//LOGW("suc generate_key");
}
	
/** 对两个数据做异或
 * @data1 输入数据1, 同时返回的异或结果也写入到这里
 * @data2 输入数据2
 * @xorlen 参与异或的数据长度, 目前只能为16
 * @return 成功返回0
 */
int xordata(char *data1, char *data2, int xorlen) {
    char *p1 = data1;
    char *p2 = data2;
    char tmp1[2] = {0}; 
    char tmp2[2] = {0}; 
    int item1 = 0, item2 = 0; 
    int res = 0; // 每字节异或结果
    //char check[20] = {0}; 

    if (xorlen != 16) {
        return -1;  
    }    
    //memcpy(check, data1, 16); 
    int i = 0;
    for (i = 0; i < xorlen; i++, p1++, p2++) {
        sprintf(tmp1, "%c", *p1);
        sprintf(tmp2, "%c", *p2);
        item1 = (int)strtoul(tmp1, 0, 16); 
        item2 = (int)strtoul(tmp2, 0, 16); 
        res = item1 ^ item2;
        sprintf(tmp1, "%X", res);
        *p1 = tmp1[0];
    }    
    return 0;   
}
/** 公钥加密
 * @in 输入数据
 * @ilen 输入数据长度
 * @pubkey 公钥数据
 * @pkeylen 公钥数据长度
 * @out 输出数据
 * @outlen 输出数据长度
 * @return 成功返回0
 */
int  qfsdk_enc_with_pub_key(char *in, int ilen, const char *pubkey, unsigned long exponent, char *out, int *outlen)
{
    RSA *key;
//    // 更新版本就更新key?
//    const char *n = "C5C1BB2EF768C9B00905B8B961E0A0DEB0CED0FBBB077A94FB235C98808A1CE71F7666F0B2BA39623B771EBF5C32C4559554D0936AA978894D48B98D81181C59FA8ADA3959CB0624EAEEC262DB2D0F49B038945EA5DF73122741E8ED74E51CCD05DEE16F640C69B3E4D30459BFDFD48CEA3EAFDF585568BC3FC183162EDF5655";
    const char *n = pubkey;
    unsigned long e = exponent;
//    unsigned long e = 65537;
    BIGNUM *bne, *bnn;
//    printf("\n\n\n\n\n");
//    printf("\n------输入-------");
//    printf("\nin = %s", in);
//    printf("\nin = %d", ilen);
//    printf("\nin = %s", n);
//    printf("\ne = %ld", e);
//    printf("\n------end-------");
    
    int ret;
    
    bne = BN_new();
    bnn = BN_new();
    if (bne == NULL || bnn == NULL) {
        return -1;
    }
    key = RSA_new();
    if (key == NULL) {
        return -1;
    }
    key->e = bne;
    key->n = bnn;
    
    ret = BN_set_word(bne, e);
    BN_hex2bn(&bnn, n);
    
    ret = RSA_public_encrypt(ilen, (unsigned char *)in, (unsigned char *)out, key, RSA_PKCS1_PADDING);
    RSA_free(key);
    if (ret < 0) {
        return -2;
    }
    
    *outlen = ret;
//    printf("\n\n\n\n\n");
//    printf("\n------输出-------");
//    printf("\nin = %s", out);
//    printf("\ne = %d", ret);
//    printf("\n------end-------");
    return 0;
}
/** 公钥加密
 * @in 输入数据
 * @ilen 输入数据长度
 * @out 输出数据
 * @outlen 输出数据长度
 * @return 成功返回0
 */
int qfsdk_pub_enc(char *in, int ilen, char *out, int *outlen) {
    RSA *key;
    // 更新版本就更新key?
    const char *n = "C5C1BB2EF768C9B00905B8B961E0A0DEB0CED0FBBB077A94FB235C98808A1CE71F7666F0B2BA39623B771EBF5C32C4559554D0936AA978894D48B98D81181C59FA8ADA3959CB0624EAEEC262DB2D0F49B038945EA5DF73122741E8ED74E51CCD05DEE16F640C69B3E4D30459BFDFD48CEA3EAFDF585568BC3FC183162EDF5655";
    //const char *n = "9EDBE8D8CF80B9CB81966E14D94560C34801558E17222FEBC7117800E8B04413243B838C001F22911679441AE0C3ABDFE4EA9F492CB76E3C2883289084ECDEEF6441967309B646D79449E6FB0F25F19F5E16AD14B7C92F73D173938959B970E00F3CA9E1A019A407278CB7F87C4D7944D4D1CE7D6D6414DF7583A2730E4DA7D9";
    unsigned long e = 65537;
    BIGNUM *bne, *bnn;
    int ret;

    bne = BN_new();
    bnn = BN_new();
    if (bne == NULL || bnn == NULL) {
        return -1;
    }
    key = RSA_new();
    if (key == NULL) {
        return -1;
    }
    key->e = bne;
    key->n = bnn;

    ret = BN_set_word(bne, e);
    BN_hex2bn(&bnn, n);

    ret = RSA_public_encrypt(ilen, (unsigned char *)in, (unsigned char *)out, key, RSA_PKCS1_PADDING);
    RSA_free(key);
    if (ret < 0) {
        return -2;
    }
    *outlen = ret;
    return 0;
}

/** 公钥解密
 * @in 输入数据
 * @ilen 输入数据长度
 * @out 输出解密后数据
 * @outlen 输出解密后数据的长度
 * @return 成功返回0
 */
int qfsdk_pub_dec(char *in, int ilen, char *out, int *outlen)
{
    RSA *key;
    const char *n = "C5C1BB2EF768C9B00905B8B961E0A0DEB0CED0FBBB077A94FB235C98808A1CE71F7666F0B2BA39623B771EBF5C32C4559554D0936AA978894D48B98D81181C59FA8ADA3959CB0624EAEEC262DB2D0F49B038945EA5DF73122741E8ED74E51CCD05DEE16F640C69B3E4D30459BFDFD48CEA3EAFDF585568BC3FC183162EDF5655";
    //const char *n = "9EDBE8D8CF80B9CB81966E14D94560C34801558E17222FEBC7117800E8B04413243B838C001F22911679441AE0C3ABDFE4EA9F492CB76E3C2883289084ECDEEF6441967309B646D79449E6FB0F25F19F5E16AD14B7C92F73D173938959B970E00F3CA9E1A019A407278CB7F87C4D7944D4D1CE7D6D6414DF7583A2730E4DA7D9";
    
    unsigned long e = 65537;
    BIGNUM *bne, *bnn;
    int ret;

    bne = BN_new();
    bnn = BN_new();
    if (bne == NULL || bnn == NULL) {
        return -1;
    }
    key = RSA_new();
    if (key == NULL) {
        return -2;
    }
    key->e = bne;
    key->n = bnn;

    ret = BN_set_word(bne, e);
    BN_hex2bn(&bnn, n);
    ret = RSA_public_decrypt(ilen, (unsigned char *)in, (unsigned char *)out, key, RSA_PKCS1_PADDING);
    RSA_free(key);
    if (ret < 0) {
        return -3;
    }
    *outlen = ret;
    return 0;
}

/** 数据签名
 * @buff 输入数据
 * @blen 输入数据长度
 */
int qfsdk_client_sign(char *buff, int blen)
{
    int packlen = 0;
    char *ptr = buff;
    unsigned char hash[20+1] = {0};
    int enclen = 0;
    int ret;

    packlen = *(int *)ptr;
    if (packlen != blen - sizeof(int)) {
        return -1;
    }
    ptr += sizeof(int);

    SHA_CTX s;
    SHA1_Init(&s);
    SHA1_Update(&s, ptr, packlen);
    SHA1_Final(hash, &s);

    ret = qfsdk_pub_enc((char*)hash, 20, ptr+packlen, &enclen);
    if (ret < 0) {
        return -2;
    }
    //*(int *)buff = packlen + sizeof(int) + enclen;
    *(int *)buff = packlen + enclen;
    return 0;
}

/** 验证签名
 * @buff 输入数据
 * @blen 输入数据长度
 * @return 返回0表示验证成功，否则失败 
 */
int qfsdk_client_verify(char *buff, int blen)
{
    char ssign[256] = {0};
    unsigned char hash[20+1] = {0};
    int  sslen = 0;
    char *ptr = buff;
    int  plen = 0;
    int  ret;

    plen = *(int *)ptr;
    if (plen != blen-sizeof(int)) {
        return -3;
    }
    ptr += sizeof(int);

    ptr += plen-128;
    ret = qfsdk_pub_dec(ptr, 128, ssign, &sslen);
    if (ret < 0) {
        return -1;
    }
    SHA_CTX s; 
    SHA1_Init(&s);
    SHA1_Update(&s, buff + sizeof(int), plen-128);
    SHA1_Final(hash, &s);

    if (memcmp(hash, ssign, sslen) < 0) {
        return -2;
    }
    return 0; 
}
/** AES256加解密
 * @key 秘钥
 * @keylen 秘钥长度
 * @in 输入待加密/解密数据
 * @ilen 输入数据长度 
 * @out 返回的加密/解密数据
 * @outlen 返回的加密/解密数据长度
 * @type 加密或解密标记。AES_ENCRYPT表示加密, AES_DECRYPT表示解密
 */
int qfsdk_aes_cbc(unsigned char *key, int keylen, unsigned char *in, int ilen, unsigned char *out, int *outlen, int type)
{
    //unsigned char key[AES_BLOCK_SIZE];
    //unsigned char buff[AES_BLOCK_SIZE];
    unsigned char iv[AES_BLOCK_SIZE];
    AES_KEY  aes;
    //char     inbuff[10240] = {0};
    //char     outbuff[10240] = {0};
    int      enclen = 0;

    if (keylen != 32) {
        //ZCWARN("key len error: %d\n", keylen);
        return -1; 
    }   
    
    if (type == AES_ENCRYPT) {
        if (AES_set_encrypt_key((const unsigned char *)key, 256, &aes) < 0) {
            //ZCWARN("set aes key error\n");
            return -2; 
        }   
    } else if (type == AES_DECRYPT) {
        if (AES_set_decrypt_key((const unsigned char *)key, 256, &aes) < 0) {
            //ZCWARN("set aes key error\n");
            return -3; 
        }   
    }   

    unsigned char *inptr = NULL;
    unsigned char *ouptr = NULL;
    //enclen = (ilen / 16 + ((ilen % 16) ? 1 : 0)) * 16;
    //ZCINFO("enclen: %d\n", enclen);
    /*if (type == AES_ENCRYPT) {
        if ((ilen + 1) % AES_BLOCK_SIZE == 0) {
            enclen = ilen + 1;
        } else {
            enclen = ((ilen + 1) / AES_BLOCK_SIZE + 1) * AES_BLOCK_SIZE;
        }
    } else if (type == AES_DECRYPT) {
        enclen = ilen;
    }*/
    //计算加密段的长度
    if (type == AES_ENCRYPT) {
        if (ilen % AES_BLOCK_SIZE == 0) {
            enclen = ilen;
        } else {
            enclen = (ilen / AES_BLOCK_SIZE  + ((ilen % AES_BLOCK_SIZE) ? 1: 0)) * AES_BLOCK_SIZE;
        }   
    } else if (type == AES_DECRYPT) {
        enclen = ilen;
    }   

    *outlen = enclen;
    //ZCINFO("enclen: %d\n", enclen);
    memset(iv, 0x0, AES_BLOCK_SIZE);
    //memcpy(inbuff, in, ilen);
    //for (i = 0, inptr = inbuff, ouptr = out; i < enclen/AES_BLOCK_SIZE; i++, inptr+=AES_BLOCK_SIZE, ouptr+=AES_BLOCK_SIZE) {
        //memset(buff, 0x0, AES_BLOCK_SIZE);
    inptr = in; 
    ouptr = out;
        //AES_cbc_encrypt((unsigned char *)inptr, (unsigned char *)buff, enclen,  &aes, iv, type);
    //AES_cbc_encrypt((unsigned char *)inptr, (unsigned char *)out, enclen,  &aes, iv, type);
    AES_cbc_encrypt((unsigned char *)inptr, (unsigned char *)out, enclen,  &aes, iv, type);
        //memcpy(ouptr, buff, AES_BLOCK_SIZE);
    //} 
    
    return 0;
}

/** 生成pinblock
 * @pass 密码
 * @cardno 卡号
 * @pin 返回的pinblock数据
 * @return 成功返回0
 */
static int generate_pin_block(char *pass, char *cardno, char *pin)
{   
    int plen;
    int clen;
    char pbuff[128] = {0};
    char cbuff[128] = {0};

    plen = (int)strlen(pass);
    clen = (int)strlen(cardno);
    if (plen > 6 || clen > 128 || clen < 13) {
        printf("input data error\n");
        return -1; 
    }   
    sprintf(pbuff, "%d%d%s", 0, plen, pass);
    int flen = 16 - plen - 2;
    char *pptr = pbuff + 2 + plen;
    memset(pptr, 'F', flen);
    char *cptr = cardno + clen - 13; 
    memset(cbuff, '0', 4); 
    memcpy(cbuff+4, cptr, 12);

    xordata(pbuff, cbuff, 16);

    memcpy(pin, pbuff, 16);
    return 0;
}

/** des加解密
 * @key 秘钥
 * @input 输入待加密的数据
 * @ilen 输入数据长度
 * @out 返回加密后的数据
 * @outsize 返回加密数据的buffer大小
 * @outlen 返回数据长度
 * @ed_flag 加密或解密标记。 DES_ENCRYPT 表示加密，DES_DECRYPT 表示解密
 * @return 成功返回0
 */
int des_ec_de(char *key, char *input, size_t ilen, char *out, size_t outsize, size_t *outlen, int ed_flag)
{
    char buff[2048] = {0};
    char desout[2048] = {0};
    int  rlen = 0;
    //DES_key_schedule ks;

    /*if (strlen(key) != 8) {
        ZCWARN("key must 8 byte\n");
        return -1;
    }*/
    if (ilen > sizeof(buff)) {
        return -1; 
    }   
    rlen = (ilen / 8 + ((ilen % 8) ? 1 : 0)) * 8;
    //ZCINFO("rlen: %d\n", rlen);
    memcpy(buff, input, rlen);
    *outlen = rlen; 
    //DES_set_key_unchecked((const_DES_cblock *)key, &ks);
    //DES_cblock ivec;
    //memset(&ivec, 0, sizeof(DES_cblock));
    char *sp, *dp;
    int i;
    for (i = 0, sp = buff, dp = desout; i < rlen / 8; i++, sp+=8, dp+=8) {
        //char bcd[1024] = {0};
        //zc_binary2bcd(sp, 8, bcd);
        DES_key_schedule ks; 
        DES_set_key_unchecked((const_DES_cblock *)key, &ks);
        //DES_cblock ivec;
        //memset(&ivec, 0, sizeof(DES_cblock));

        //char bcd[1024] = {0};
        //zc_binary2bcd(sp, 8, bcd);
        //ZCINFO("--------------------bcd: %s\n", bcd);
        //DES_ncbc_encrypt((unsigned char *)sp, (unsigned char *)dp,  8, &ks, &ivec, ed_flag);
        unsigned char src[8] = {0};
        memcpy(src, sp, 8); 
        unsigned char dst[8] = {0};
        //DES_ecb_encrypt((unsigned char *)sp, (unsigned char *)dp, &ks, ed_flag);
        DES_ecb_encrypt(&src, &dst, &ks, ed_flag);
        memcpy(dp, dst, 8); 
        //zc_binary2bcd(dp, 8, bcd);
        //ZCINFO("--------------------result: %s\n", bcd);
        //DES_set_key_unchecked((const_DES_cblock *)key, &ks);
        //DES_cblock ivec;
        //memset(&ivec, 0, sizeof(DES_cblock));
    }
    memcpy(out, desout, rlen);
    return 0;
}

/** 3des加密
 * @result 返回加密的数据
 * @mkey 秘钥
 * @input 输入数据
 * @return 成功返回0，失败返回负值
 */
static int des3_enc(char *result, char *mkey, char *input)
{
    long  ret = 0;
    char binput[2049] = {0};
    int  ilen = strlen(input)/2;
    char high[32] = {0};
    char low[32] = {0};
    char bhigh[32] = {0}; 
    char blow[32] = {0}; 

    if (ilen > 1024) {
        return -1;
    }    
    if (strlen(mkey) != 32) {
        return -2;
    }    
 
    memcpy(high, mkey, 16); 
    memcpy(low, mkey+16, 16); 

    zc_bcd2binary(high, bhigh);
    zc_bcd2binary(low, blow);
    zc_bcd2binary(input, binput);

    char out1[1024] = {0}; 
    char out2[1024] = {0}; 
    char out3[1024] = {0}; 
    char ascii[513] = {0}; 
    size_t outlen = 0; 

    // 3des加密为三次des的 加密，解密，加密
    ret = des_ec_de(bhigh, binput, ilen, out1, sizeof(out1), &outlen, DES_ENCRYPT);
    if (ret < 0) { 
        return -3;
    }    
    ret = zc_binary2bcd(out1, outlen, ascii);
    if (ret < 0) {
        return ret;
    }

    ret = des_ec_de(blow, out1, ilen, out2, sizeof(out2), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return -4;
    }
    ret = zc_binary2bcd(out2, outlen, ascii);
    if (ret < 0) {
        return ret;
    }

    ret = des_ec_de(bhigh, out2, ilen, out3, sizeof(out3), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return -5;
    }
    ret = zc_binary2bcd(out3, outlen, ascii);
    if (ret < 0) {
        return ret;
    }
    
    sprintf(result, "%s", ascii);
    return 0;
}


/** 3des解密
 * @result 返回解密后数据
 * @mkey 秘钥
 * @input 输入数据
 * @return 成功返回0， 失败返回-1
 */
/** 暂时有服务器端解密
static int des3_dec(char *result, char *mkey, char *input)
{
    long ret;
    char binput[2049] = {0};
    int  ilen = strlen(input)/2;
    char high[32] = {0};
    char low[32] = {0};
    char bhigh[32] = {0};
    char blow[32] = {0};

    if (ilen > 1024) {
        return -1;
    }
    if (strlen(mkey) != 32) {
        return -2;
    }

    memcpy(high, mkey, 16);
    memcpy(low, mkey+16, 16);
    //ZCINFO("high: %s\n", high);
    //ZCINFO("low: %s\n", low);

    zc_bcd2binary(high, bhigh);
    zc_bcd2binary(low, blow);
    zc_bcd2binary(input, binput);

    char out1[1024] = {0};
    char out2[1024] = {0};
    char out3[1024] = {0};
    char ascii[513] = {0};
    size_t outlen = 0;

    // 解密
    ret = des_ec_de(bhigh, binput, ilen, out1, sizeof(out1), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return -3;
    }
    zc_binary2bcd(out1, outlen, ascii);

    // 加密
    ret = des_ec_de(blow, out1, ilen, out2, sizeof(out2), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return -4;
    }
    ret = zc_binary2bcd(out2, outlen,  ascii);
    if (ret < 0) {
        return ret;
    }

    // 解密
    ret = des_ec_de(bhigh, out2, ilen, out3, sizeof(out3), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return -5;
    }
    ret = zc_binary2bcd(out3, outlen, ascii);
    if (ret < 0) {
        return ret;
    }

    sprintf(result, "%s", ascii);
    return 0;
}
**/
 
/** 数据离散
 * @result 离散后的返回数据
 * @mkey 离散用的key
 * @dsp
 * @return
 */
int data_dsp(char *result, char *mkey, char *dsp)
{
    long ret; 
    char high[1024] = {0}; 
    char low[1024] = {0}; 
    char bhigh[1024] = {0}; 
    char blow[1024] = {0}; 
    char bdsp[1024] = {0}; 

    memcpy(high, mkey, 16); 
    memcpy(low, mkey+16, 16); 

    zc_bcd2binary(high, bhigh); 
    zc_bcd2binary(low, blow);
    zc_bcd2binary(dsp, bdsp);
    
    size_t outlen = 0; 
    char out1[128] = {0}; 
    char out2[128] = {0}; 
    char out3[128] = {0}; 
    char ascii[128] = {0}; 
    
    //高位加密
    ret = des_ec_de(bhigh, bdsp, 8, out1, sizeof(out1), &outlen, DES_ENCRYPT);
    if (ret < 0) { 
        return -1;
    }    
    zc_binary2bcd(out1, 8, ascii);
    if (ret < 0) { 
        return ret; 
    }    
    // 低位解密
    ret = des_ec_de(blow, out1, 8, out2, sizeof(out2), &outlen, DES_DECRYPT);
    if (ret < 0) { 
        return -2;
    }    
    zc_binary2bcd(out2, 8, ascii);
    if (ret < 0) { 
        return ret; 
    }    
    // 高位加密
    ret = des_ec_de(bhigh, out2, 8, out3, sizeof(out3), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return -3;
    }
    zc_binary2bcd(out3, 8, ascii);
    if (ret < 0) {
        return ret;
    }

    char *rptr = result;
    sprintf(rptr, "%s", ascii);
    rptr += strlen(ascii);

    char tmpdsp[128] = {0};
    memcpy(tmpdsp, dsp, strlen(dsp));
    xordata(tmpdsp, (char *)"FFFFFFFFFFFFFFFF", 16);

    memset(out1, 0, sizeof(out1));
    memset(out2, 0, sizeof(out2));
    memset(out3, 0, sizeof(out3));

    memset(bdsp, 0, sizeof(bdsp));
    zc_bcd2binary(tmpdsp, bdsp);

    // 高位加密
    ret = des_ec_de(bhigh, bdsp, 8, out1, sizeof(out1), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return -4;
    }
    ret = zc_binary2bcd(out1, 8, ascii);
    if (ret < 0) {
        return ret;
    }

    // 低位解密
    ret = des_ec_de(blow, out1, 8, out2, sizeof(out2), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return -5;
    }
    ret = zc_binary2bcd(out2, 8, ascii);
    if (ret < 0) {
        return ret;
    }
    // 高位加密
    ret = des_ec_de(bhigh, out2, 8, out3, sizeof(out3), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return -6;
    }
    ret = zc_binary2bcd(out3, 8, ascii);
    if (ret < 0) {
        return ret;
    }
    
    sprintf(rptr, "%s", ascii);
    return 0; 
}

/** 生成随机数
 * @rand 返回的随机数，为16进制表示形式
 * @return 成功返回0
 */
int gen_rand(char *randbuf)
{
    char item[] = {'0',  '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    //unsigned int seed = 0;
    //struct timeval start1;
    //gettimeofday(&start1, NULL);
    //seed = start1.tv_sec  +  start1.tv_usec;
    //int i = 0;
    //for (i = 0; i < 8; i++) {
    //    //int index = rand_r(&seed) % 16;
    //    int index = lrand48() % 16;
    //    rand[i] = item[index];
    //}
    unsigned int now = time(NULL);
    int i=0, index; 
    srand(now);

    for (i=0; i<8; i++) {
        index = rand() % 16;
        randbuf[i] = item[index];
    }
    return 0;
}

/** 对密码加密
 * @cardno 卡号
 * @pass   密码明文
 * @tsk    transfer key
 * @enc_pinkey  加密的pinkey
 * @clisn  客户端流水号
 * @psamid psamid
 * @enc_pin 输出加密后的密码
 * @return 0表示成功，小于0为失败
 */
int qfsdk_pin_enc(char *cardno, char *pass, char *tsk, char *enc_pinkey, char *clisn, char *psamid, char *enc_pin)
{
    int  ret;
    char cardpin[32] = {0};
    char aes_key[128] = {0};
    char enc_pinkey_binary[256] = {0};
    char out[64] = {0};
    int  olen;
    char pinkey[64] = {0};
    char bankid[32] = {0};
    char randstr[32] = {0};
    
    if (strlen(clisn) != 6 || strlen(cardno) < 12 || strlen(pass) != 6) {
        return -1;
    }
    ret = generate_pin_block(pass, cardno, cardpin);
    if (ret < 0) {
        return ret;
    }
    zc_bcd2binary(tsk, aes_key);
    zc_bcd2binary(enc_pinkey, enc_pinkey_binary);

    // 解出pinkey明文
    ret = qfsdk_aes_cbc((unsigned char *)aes_key, strlen(enc_pinkey)/2, 
                (unsigned char*)enc_pinkey_binary, strlen(enc_pinkey)/2, 
                (unsigned char*)out, &olen, AES_DECRYPT);
    memcpy(pinkey, out, 32);
    
    //离散数据1, bankid是固定值
    memcpy(bankid, "3635363030303031", 16);
    //离散数据2, psamid
    char psamid_bcd[32] = {0};
    if (strlen(psamid) == 8) {
        zc_binary2bcd(psamid, 8, psamid_bcd);
    } else {
        memcpy(psamid_bcd, psamid, 16);
    }
    //离散数据3, clisn
    char clin_bcd [7] = {0};
    char rand_buf[9]  = {0};
    zc_binary2bcd(clisn+3, 3, clin_bcd);
    gen_rand(rand_buf);
    
    sprintf(randstr, "FF%s%s", rand_buf, clin_bcd); 

    // 生成实际用来加密的工作秘钥
    char workkey[33] = {0};
    //三次离散
    data_dsp(workkey, pinkey, bankid);
    data_dsp(workkey, workkey, psamid_bcd);
    data_dsp(workkey, workkey, randstr);
    // 3des加密    
    des3_enc(enc_pin, workkey, cardpin);
    sprintf(enc_pin + 16, rand_buf, 8);
    return 0;
}

/**
 * http请求数据打包，给v2接口使用
 * @key 秘钥
 * @keylen 秘钥长度
 * @input 输入数据
 * @ilen 输入数据长度
 * @encflag 加密标记。PACK_CIPHER_DATA表示内容数据加密，PACK_NO_CIPHER_DATA不加密。
 *          因为transfer_key在登陆之后才有，所有登陆之前的数据是只打包不加密的
 * 包结构：
 * version 0
 * 报文长度(4B) + 内容加密标记(4B) + 内容长度(4B) + 内容 + 签名(128B)
 * version 1 
 * 报文长度(4B) + 版本(1B) + 选项(3B) + 内容长度(4B) + 内容 + 签名(128B)
 * 版本：默认0, 新版本+1  
 */
int qfsdk_pack(char *key, int keylen, char *input, int ilen, char *out, int *olen, int encflag)
{
    char *ptr = out; 
    char *packlen = ptr; 
    int  outlen;
    char *buff; 
    int version = 0;
    // 用于加密数据临时存储: 长度(4Byte)+输入数据(ilen)+结尾\0(1Byte)
    // aes加密后长度会变
    buff = (char *)malloc(ilen + sizeof(int)*3 + 128 + 4096);
    if (buff == NULL) {
        return -1; 
    }    
    memset(buff, 0x0, ilen+sizeof(int)+1);
    //skip包header
    ptr += sizeof(int);
    //写入版本和标志
    *(int *)ptr = (version << 24) | encflag;
    ptr += sizeof(int);
    //密文或者明文长度
    char *enclen = ptr; 
    ptr += sizeof(int);
    
    if (encflag == PACK_CIPHER) {
        char *pbuf = buff;
        *(int *)pbuf = ilen;
        pbuf += sizeof(int);
        //ZCINFO("ilen: %d\n", ilen);
        memcpy(pbuf, input, ilen);
        qfsdk_aes_cbc((unsigned char *)key, keylen, (unsigned char *)buff, ilen+sizeof(int), 
                    (unsigned char *)ptr, &outlen, 1);  
        *(int *)enclen = outlen;
        //*(int *)packlen = outlen + sizeof(int)*2;
        *(int *)packlen = outlen + sizeof(int)*2; // 写入包长度
        //*olen = outlen + sizeof(int)*2;
        *olen = outlen + sizeof(int)*3;
    } else if (encflag == PACK_RAW) {
        memcpy(ptr, input, ilen);
        *(int *)enclen = ilen;
        *(int *)packlen = ilen + sizeof(int)*2;
        *olen = ilen + sizeof(int)*3; 
    } else { 
        free(buff); 
        return -2; 
    }   
    qfsdk_client_sign(out, *olen);
    *olen += 128;
    //printf("outlen: %d\n", *olen);
    free(buff);
    return 0;
}

/**
 * http请求数据解包
 * @key 秘钥
 * @keylen 秘钥长度
 * @input 输入数据
 * @ilen 输入数据长度
 * @out 输出数据
 * @olen 输出数据长度
 */
int qfsdk_unpack(char *key, int keylen, char *input, int ilen, char *out, int *olen)
{
    //char buff[10240*4] = {0};
    char *ptr = input;
    int  outlen;
    int  encflag;
    char *buff;

    int ret = qfsdk_client_verify(input, ilen);
    if (ret < 0) {
        return -1;
    }
    buff = (char *)malloc(ilen+sizeof(int)+1);
    if (buff == NULL) {
        //ZCWARN("malloc buff size error");
        return -1;
    }
    memset(buff, 0x0, ilen+sizeof(int)+1);
    //pack header
    ptr += sizeof(int);
    //密文或者明文标示
    int tmp = *(int*)ptr;
    printf("encflag:%x", tmp);
    encflag = tmp & 0x00FFFFFF;
    printf("encflag:%d", encflag);
    ptr += sizeof(int);
    //明文或者密文长度 
    int enclen = *(int *)ptr;
    printf("enclen:%x", enclen);
    //ZCINFO("enclen: %d\n", enclen);
    ptr += sizeof(int);
    if (encflag == PACK_CIPHER) {
        int ret = qfsdk_aes_cbc((unsigned char *)key, keylen, (unsigned char *)ptr, enclen, (unsigned char *)buff, &outlen, 0);
        printf("aes_cbc ret:%d", ret);
        //ZCINFO("outlen: %d\n", outlen);
        char *pbuff = buff;
        *olen = *(int *)pbuff;
        //ZCINFO("olen: %d", *olen);
        if (*olen < 0 || *olen > ilen) {
            free(buff);
            return -2;
        }
        //ZCINFO("olen: %d\n", *olen);
        memcpy(out, pbuff+sizeof(int), *olen);
    } else if (encflag == PACK_RAW) {
        memcpy(out, ptr, enclen);
        *olen = enclen;
    } else {
        free(buff);
        return -3;
    }
    free(buff);
    return 0;
}

int qfsdk_aes_key_random(char *out)
{
    char item[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
    unsigned int now = time(NULL);
    int outi = 0;
    int i=0, index; 
    srand(now);

    for (i=0; i<32; i++) {
        index = rand() % 16;
        out[outi] = item[index];
        outi++;
    }
    out[outi] = 0;
    return outi;
}
int xdec(char *result, char *mkey, char *input)
{
    int ret;
    char binput[2049] = {0};
    int  ilen = strlen(input)/2;
    char high[32] = {0};
    char low[32] = {0};
    char bhigh[32] = {0};
    char blow[32] = {0};
    
    if (ilen > 1024) {
        return -1;
    }
    if (strlen(mkey) != 32) {
        return -1;
    }
    memcpy(high, mkey, 16);
    memcpy(low, mkey+16, 16);
    zc_bcd2binary(high, bhigh);
    zc_bcd2binary(low, blow);
    zc_bcd2binary(input, binput);
    
    char out1[1024] = {0};
    char out2[1024] = {0};
    char out3[1024] = {0};
    char ascii[513] = {0};
    size_t outlen = 0;
    ret = des_ec_de(bhigh, binput, ilen, out1, sizeof(out1), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return ret;
    }
    zc_binary2bcd(out1, outlen, ascii);
    ret = des_ec_de(blow, out1, ilen, out2, sizeof(out2), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        return ret;
    }
    ret = zc_binary2bcd(out2, outlen,  ascii);
    if (ret < 0) {
        return ret;
    }
    ret = des_ec_de(bhigh, out2, ilen, out3, sizeof(out3), &outlen, DES_DECRYPT);
    if (ret < 0) {
        return ret;
    }
    ret = zc_binary2bcd(out3, outlen, ascii);
    if (ret < 0) {
        return ret;
    }
    sprintf(result, "%s", ascii);
    return 0;
}

int xenc(char *result, char *mkey, char *input)
{
    int  ret = 0;
    char binput[2049] = {0};
    int  ilen = (int)strlen(input)/2;
    char high[32] = {0};
    char low[32] = {0};
    char bhigh[32] = {0};
    char blow[32] = {0};
    
    if (ilen > 1024) {
        //ZCWARN("input data too long\n");
        return -1;
    }
    if (strlen(mkey) != 32) {
        //ZCWARN("input key len error\n");
        return -1;
    }
    
    //ZCINFO("mkey: %s\n", mkey);
    //ZCINFO("input: %s\n", input);
    memcpy(high, mkey, 16);
    memcpy(low, mkey+16, 16);
    //ZCINFO("high: %s\n", high);
    //ZCINFO("low: %s\n", low);
    //ascii2binary(bhigh, high);
    zc_bcd2binary(high, bhigh);
    //ascii2binary(blow, low);
    zc_bcd2binary(low, blow);
    //ascii2binary(binput, input);
    zc_bcd2binary(input, binput);
    
    char out1[1024] = {0};
    char out2[1024] = {0};
    char out3[1024] = {0};
    char ascii[513] = {0};
    size_t outlen = 0;
    
    ret = des_ec_de(bhigh, binput, ilen, out1, sizeof(out1), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        //ZCWARN("des_ec_de error\n");
        return -1;
    }
    //ret = binary2ascii(ascii, out1, ilen);
    //ret = zc_binary2bcd(out1, ilen, ascii);
    ret = (int)zc_binary2bcd(out1, (int)outlen, ascii);
    if (ret < 0) {
        //ZCWARN("binary2ascii error\n");
        return ret;
    }
    //ZCINFO("ascii: %s\n", ascii);
    
    ret = des_ec_de(blow, out1, ilen, out2, sizeof(out2), &outlen, DES_DECRYPT);
    if (ret < 0) {
        //ZCWARN("des_ec_de error\n");
        return -1;
    }
    //ret = binary2ascii(ascii, out2, ilen);
    //ret = zc_binary2bcd(out2, ilen, ascii);
    ret = (int)zc_binary2bcd(out2, (int)outlen, ascii);
    if (ret < 0) {
        //ZCWARN("binary2ascii error\n");
        return ret;
    }
    
    //ZCINFO("ascii: %s\n", ascii);
    
    ret = des_ec_de(bhigh, out2, ilen, out3, sizeof(out3), &outlen, DES_ENCRYPT);
    if (ret < 0) {
        //ZCWARN("des_ec_de error\n");
        return -1;
    }
    //ret = binary2ascii(ascii, out3, ilen);
    //ret = zc_binary2bcd(out3, ilen, ascii);
    ret = (int)zc_binary2bcd(out3, (int)outlen, ascii);
    if (ret < 0) {
        //ZCWARN("binary2ascii error\n");
        return ret;
    }
    //ZCINFO("ascii: %s\n", ascii);
    sprintf(result, "%s", ascii);
    return 0;
}

int genchcv_x(char *key, char *ret)
{
    char gen[32] = {0};
    sprintf(gen, "%s", "0000000000000000");
    int result = xenc(ret, key, gen);
    printf("%s", ret);
    return result;
}
int genencTmk(char *key, char *ret, char *inc)
{
//    char gen[32] = {0};
//    sprintf(gen, "%s", in);
    int result = xenc(ret, key, inc);
    printf("%s", ret);
    return result;
}



