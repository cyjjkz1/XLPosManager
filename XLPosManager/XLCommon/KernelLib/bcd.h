#ifndef ZOCLE_ENC_BCD_H
#define ZOCLE_ENC_BCD_H

#include <stdio.h>

long zc_bcd2binary(char *hexstr, char *binary);
long zc_binary2bcd(char *binary, int binlen, char *bcd);

#endif
