
%{
#include <string>
#include <iostream>
using namespace std;

extern int linha;
#include "sintatico.tab.h"
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA  [a-zA-Z]
ID     {LETRA}({LETRA}|{DIGITO})*

%%

"//".* { /* Ignora comentários de uma linha */ }
"\n"                 { linha++; }
{ESPACO}+            {}

"int"                { return TK_INT; }
"float"              { return TK_FLOAT; }
"bool"|"boolean"     { return TK_BOOL_TYPE; }
"char"               { return TK_CHAR_TYPE; }
"true"               { return TK_TRUE; }
"false"              { return TK_FALSE; }

"<="                 { return TK_MENORIG; }
">="                 { return TK_MAIORIG; }
"!="                 { return TK_DIFF; }
"=="                 { return TK_IGUAL; }
"&&"                 { return TK_ELOG; }
"||"                 { return TK_OLOG; }

";"                  { return *yytext; }
"="                  { return *yytext; }
"+"                  { return *yytext; }
"-"                  { return *yytext; }
"*"                  { return *yytext; }
"/"                  { return *yytext; }
"("                  { return *yytext; }
")"                  { return *yytext; }
"<"                  { return *yytext; }
">"                  { return *yytext; }
"!"                  { return *yytext; }

"print"              { return TK_PRINT; }

\'.\'                { yylval.label = yytext; return TK_CHAR_VAL; }
{DIGITO}+\.{DIGITO}+ { yylval.label = yytext; return TK_REAL; }
{DIGITO}+            { yylval.label = yytext; return TK_NUM; }
{ID}                 { yylval.label = yytext; return TK_ID; }

.                    { fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%
