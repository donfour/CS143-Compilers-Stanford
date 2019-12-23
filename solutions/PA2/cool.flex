/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */

%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <math.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;
int string_length;
int null_character_found;

int comment_nesting;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

/* multiple-character operators */
DARROW  =>
ASSIGN  <-
LE      <=

/* whitespace */
WHITESPACE	[ \f\r\t\v]+

/* keywords */
TRUE        t[Rr][Uu][Ee]
FALSE       f[Aa][Ll][Ss][Ee]
CLASS       [Cc][Ll][Aa][Ss][Ss]
ELSE        [Ee][Ll][Ss][Ee]
FI          [Ff][Ii]
IF          [Ii][Ff]
IN          [Ii][Nn]
INHERITS    [Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]
LET         [Ll][Ee][Tt]
LOOP        [Ll][Oo][Oo][Pp]
POOL        [Pp][Oo][Oo][Ll]
THEN        [Tt][Hh][Ee][Nn]
WHILE       [Ww][Hh][Ii][Ll][Ee]
CASE        [Cc][Aa][Ss][Ee]
ESAC        [Ee][Ss][Aa][Cc]
OF          [Oo][Ff]
NEW         [Nn][Ee][Ww]
ISVOID      [Ii][Ss][Vv][Oo][Ii][Dd]
NOT         [Nn][Oo][Tt]
ESCAPE      \\

/* start conditions */
%x str str_err comment inline_comment

%%

 /* eat up whitespace */
{WHITESPACE} ;

 /* increment line number */
<INITIAL,comment>"\n" curr_lineno++;

 /*
  *  Inline comments
  */
"--" {
    BEGIN(inline_comment);
}

<inline_comment>[^\n]* ;

<inline_comment>\n {
    curr_lineno++;
    BEGIN(INITIAL);
}

 /*
  *  Nested comments
  */
"(*" {
    comment_nesting++;
    BEGIN(comment);
}

"*)" {
    cool_yylval.error_msg = "Unmatched *).";
    return ERROR;
}

<comment>"(*" {
    comment_nesting++;
}

<comment>"*)" {
    comment_nesting--;
    if(comment_nesting==0) {
        BEGIN(INITIAL);
    }
}

<comment><<EOF>> {
    cool_yylval.error_msg = "EOF in comment.";
    BEGIN(INITIAL);
    return ERROR;
}

<comment>. ;

 /*
  *  Single characters
  */
"."     { return 46; }
"@"     { return 64; }
"~"     { return 126; }
"*"     { return 42; }
"/"     { return 47; }
"+"     { return 43; }
"-"     { return 45; }
"<"     { return 60; }
"="     { return 61; }
"{"     { return 123; }
"}"     { return 125; }
"("     { return 40; }
")"     { return 41; }
":"     { return 58; }
","     { return 44; }
";"     { return 59; }

 /*
  *  The multiple-character operators.
  */
{DARROW}    { return DARROW; }
{ASSIGN}    { return ASSIGN; }
{LE}        { return LE; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{CLASS}     { return CLASS; }
{ELSE}      { return ELSE; }
{FI}        { return FI; }
{IF}        { return IF; }
{IN}        { return IN; }
{INHERITS}  { return INHERITS; }
{LET}       { return LET; }
{LOOP}      { return LOOP; }
{POOL}      { return POOL; }
{THEN}      { return THEN; }
{WHILE}     { return WHILE; }
{CASE}      { return CASE; }
{ESAC}      { return ESAC; }
{OF}        { return OF; }
{NEW}       { return NEW; }
{ISVOID}    { return ISVOID; }
{NOT}       { return NOT; }
{TRUE}      { cool_yylval.boolean = true; return BOOL_CONST; }
{FALSE}     { cool_yylval.boolean = false; return BOOL_CONST; }

 /*
  *  Type identifiers
  */
[A-Z][a-zA-Z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

 /*
  *  Object identifiers
  */
[a-z][a-zA-Z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

 /*
  *  Integer constants
  */
[0-9]+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\" {
    string_buf_ptr = string_buf;
    string_length = 0;
    null_character_found = 0;
    BEGIN(str);
}

 /* strings */
<str>\" {
    BEGIN(INITIAL);

    if(string_length >= MAX_STR_CONST){
        cool_yylval.error_msg = "String constant too long.";
        return ERROR;
    }

    if(null_character_found){
        cool_yylval.error_msg = "String contains null character.";
        return ERROR;
    }

    *string_buf_ptr = '\0';
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return STR_CONST;
}

<str>\n {
    /* error - unterminated string constant */
    cool_yylval.error_msg = "Unterminated string constant.";
    BEGIN(INITIAL);
    curr_lineno++;
    return ERROR;
}

<str>\0 {
    /* error - string contains null character */
    null_character_found = 1;
}

 /* Note: . matches anything but newline */
<str>{ESCAPE}\n {
    *string_buf_ptr++ = '\n';
    string_length++;
    curr_lineno++;
    break;
}

<str>{ESCAPE}. {
    char matched = yytext[1];

    switch(matched){
        case 'b':
            *string_buf_ptr++ = '\b';
            string_length++;
            break;
        case 't':
            *string_buf_ptr++ = '\t';
            string_length++;
            break;
        case 'n':
            *string_buf_ptr++ = '\n';
            string_length++;
            break;
        case 'f':
            *string_buf_ptr++ = '\f';
            string_length++;
            break;
        case '\0':
            null_character_found = 1;
            break;
        default:
            *string_buf_ptr++ = matched;
            string_length++;
            break;
    }
}

<str>[^\\\n\"\0]+ {
    char *yptr = yytext;
    while ( *yptr ) {
        *string_buf_ptr++ = *yptr++;
        string_length++;
    }
}

<str><<EOF>> {
    cool_yylval.error_msg = "EOF in string constant.";
    BEGIN(INITIAL);
    return ERROR;
}

 /* ignore everything until the closing " after we've encountered an invalid character */ 
<str_err>\" {
    BEGIN(INITIAL);
}

<str_err>[^\"]+ ;

 /* invalid character - one that can't begin any token */
. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

%%
