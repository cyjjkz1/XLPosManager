#include "bcd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char hexdigits[] = "0123456789ABCDEF";

static unsigned char str_to_char (char a, char b)
{
    char encoder[3] = {'\0','\0','\0'};
    encoder[0] = a;
    encoder[1] = b;
    return (char) strtol(encoder,NULL,16);
}

long zc_bcd2binary(char *bcd, char *binary)
{
    //int length = strlen(hexstr);
    char *index = binary;

    while ((*bcd) && (*(bcd +1))) {
        char a=(*bcd);
        char b=(*(bcd +1));
        *index = str_to_char(a, b); 
        index++;
        bcd+=2;
    }   
    *index = '\0';

    return index-binary;
}
// 调用者保证bcd空间
long zc_binary2bcd(char *binary, int binlen, char *bcd)
{
    char *bytes = binary;
    char *hex = bcd;

    int i;
    for (i=0; i<binlen; ++i){
        const unsigned char c = *bytes++;
        *hex++ = hexdigits[(c >> 4) & 0xF];
        *hex++ = hexdigits[(c ) & 0xF];
    }   
    *hex = 0;
    return hex-bcd;
}
