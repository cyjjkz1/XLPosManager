#define PACK_CIPHER 1
#define PACK_RAW	0

#ifdef WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT 
#endif

extern int ver;

typedef unsigned char BYTE;

EXPORT void qfsdk_init();

EXPORT int  qfsdk_aes_key_random(char *out);
EXPORT int  qfsdk_aes_cbc(unsigned char *key, int keylen, unsigned char *in, int ilen, unsigned char *out, int *outlen, int type);
EXPORT int  qfsdk_pub_enc(char *in, int ilen, char *out, int *outlen);
EXPORT int  qfsdk_enc_with_pub_key(char *in, int ilen, const char *pubkey, unsigned long exponent, char *out, int *outlen);
EXPORT int  qfsdk_pub_dec(char *in, int ilen, char *out, int *outlen);

EXPORT int  qfsdk_pin_enc(char *cardno, char *pass, char *tsk, char *enc_pinkey, char *clisn, char *psamid, char *enc_pin);

EXPORT int  qfsdk_pack(char *key, int keylen, char *input, int ilen, char *out, int *olen, int encflag);
EXPORT int  qfsdk_unpack(char *key, int keylen, char *input, int ilen, char *out, int *olen);
EXPORT int  genchcv_x(char *key, char *ret);
EXPORT int xdec(char *result, char *mkey, char *input);
EXPORT int xenc(char *result, char *mkey, char *input);
EXPORT int genencTmk(char *key, char *ret, char *inc);
EXPORT int xordata(char *data1, char *data2, int xorlen);
