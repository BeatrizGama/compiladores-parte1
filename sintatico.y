
%{
#include <iostream>
#include <string>
#include <map>

using namespace std;

struct atributos
{
    string label;
    string traducao;
    string tipo;
};

#define YYSTYPE atributos

int var_temp_qnt;
int linha = 1;
string codigo_gerado;

map<string, string> tabela_simbolos;
map<string, string> tipo_temp;

int yylex(void);
void yyerror(string);
string gentempcode();

// Função auxiliar para buscar variáveis no mapa
atributos buscaSimbolo(string nomeVar) {
    if (tabela_simbolos.count(nomeVar) == 0) {
        yyerror("Variavel '" + nomeVar + "' nao declarada e usada antes de inicializacao!");
        exit(1);
    }
    atributos attr;
    attr.label = tabela_simbolos[nomeVar];
    attr.tipo = tipo_temp[attr.label];
    return attr;
}

// Função para fazer conversão implícita (Coerção) nas operações (+, -, *, /)
atributos gerarOperacaoBinaria(string op, atributos a, atributos b) {
    atributos res;
    res.traducao = a.traducao + b.traducao;
    string t_a = a.label;
    string t_b = b.label;

    // tipos iguais
    if (a.tipo == b.tipo) {
        res.tipo = a.tipo;
    }
    // Coerção Implícita
    else if ((a.tipo == "int" && b.tipo == "float") || (a.tipo == "float" && b.tipo == "int")) {
        res.tipo = "float";

        
        if (a.tipo == "int") {
            t_a = gentempcode();
            tipo_temp[t_a] = "float";
            res.traducao += "\t" + t_a + " = (float) " + a.label + ";\t// Cast Implicito\n";
        } else {
            t_b = gentempcode();
            tipo_temp[t_b] = "float";
            res.traducao += "\t" + t_b + " = (float) " + b.label + ";\t// Cast Implicito\n";
        }
    } else {
        yyerror("Tipos incompativeis para operacao: " + a.tipo + " e " + b.tipo);
        exit(1);
    }

    res.label = gentempcode();
    tipo_temp[res.label] = res.tipo;
    res.traducao += "\t" + res.label + " = " + t_a + " " + op + " " + t_b + ";\n";
    return res;
}

%}

%token TK_NUM TK_REAL TK_ID TK_INT TK_FLOAT TK_CHAR_TYPE TK_BOOL_TYPE TK_CHAR_VAL TK_TRUE TK_FALSE TK_PRINT
%token TK_MENORIG TK_MAIORIG TK_DIFF TK_IGUAL TK_ELOG TK_OLOG
%start S

%left TK_OLOG
%left TK_ELOG
%left TK_IGUAL TK_DIFF
%left '<' '>' TK_MENORIG TK_MAIORIG
%left '+' '-'
%left '*' '/'
%right CAST

%%

S : COMANDOS
  {
    codigo_gerado = "/*Compilador FOCA*/\n#include <stdio.h>\n\nint main(void) {\n";

    for(int i = 1; i <= var_temp_qnt; i++){
        string nome_t = "T" + to_string(i);
        string tipo_t = tipo_temp.count(nome_t) ? tipo_temp[nome_t] : "int";
        codigo_gerado += "\t" + tipo_t + " " + nome_t + ";\n";
    }
    codigo_gerado += "\n";

    codigo_gerado += $1.traducao;
    codigo_gerado += "\n\treturn 0;\n}\n";
  }
  ;

COMANDOS : COMANDOS COMANDO { $$.traducao = $1.traducao + $2.traducao; }
         | COMANDO          { $$.traducao = $1.traducao; }
         ;

COMANDO : DECLARACAO { $$.traducao = $1.traducao; }
        | ATRIBUICAO { $$.traducao = $1.traducao; }
        | SAIDA      { $$.traducao = $1.traducao; }
        ;

TIPO : TK_INT       { $$.tipo = "int"; }
     | TK_FLOAT     { $$.tipo = "float"; }
     | TK_BOOL_TYPE { $$.tipo = "int"; }
     | TK_CHAR_TYPE { $$.tipo = "char"; }
     ;

DECLARACAO : TIPO TK_ID ';'
  {
    if (tabela_simbolos.count($2.label) == 0) {
        string novo_t = gentempcode();
        tabela_simbolos[$2.label] = novo_t;
        tipo_temp[novo_t] = $1.tipo;
        $$.traducao = "\t// [DEBUG] Variavel " + $2.label + " criada em " + novo_t + " (Declaracao Explicita)\n";
    } else {
        yyerror("Variavel '" + $2.label + "' ja foi declarada!");
        YYABORT;
    }
  }
  | TIPO TK_ID '=' E ';'
  {
    if (tabela_simbolos.count($2.label) == 0) {
        string novo_t = gentempcode();
        tabela_simbolos[$2.label] = novo_t;
        tipo_temp[novo_t] = $1.tipo;

        string t_src = $4.label;
        string cast_code = "";

        // Coerção na inicialização (ex: float x = 10;)
        if ($1.tipo != $4.tipo) {
            if (($1.tipo == "float" && $4.tipo == "int") || ($1.tipo == "int" && $4.tipo == "float")) {
                t_src = gentempcode();
                tipo_temp[t_src] = $1.tipo;
                cast_code = "\t" + t_src + " = (" + $1.tipo + ") " + $4.label + ";\t// Cast na Inicializacao\n";
            } else {
                yyerror("Tipos incompativeis na inicializacao de '" + $2.label + "'");
                YYABORT;
            }
        }

        $$.traducao = $4.traducao + cast_code + 
                      "\t// [DEBUG] Variavel " + $2.label + " inicializada em " + novo_t + "\n" +
                      "\t" + novo_t + " = " + t_src + ";\n";
    } else {
        yyerror("Variavel '" + $2.label + "' ja foi declarada!");
        YYABORT;
    }
  }
  ;

ATRIBUICAO : TK_ID '=' E ';'
  {
    atributos var;

    // Declaração Implícita 
    if (tabela_simbolos.count($1.label) == 0) {
        string novo_t = gentempcode();
        tabela_simbolos[$1.label] = novo_t;
        tipo_temp[novo_t] = $3.tipo;
        var.label = novo_t;
        var.tipo = $3.tipo;

        $$.traducao = $3.traducao + "\t// [DEBUG] Variavel " + $1.label + " criada em " + novo_t + " (Declaracao Implicita)\n\t" + var.label + " = " + $3.label + ";\n";
    }
    // Atribuição de variável já existente
    else {
        var = buscaSimbolo($1.label);
        string t_src = $3.label;
        string cast_code = "";

        // Conversão Implícita na atribuição 
        if (var.tipo != $3.tipo) {
            if ((var.tipo == "float" && $3.tipo == "int") || (var.tipo == "int" && $3.tipo == "float")) {
                t_src = gentempcode();
                tipo_temp[t_src] = var.tipo; 
                cast_code = "\t" + t_src + " = (" + var.tipo + ") " + $3.label + ";\t// Cast Implicito na Atribuicao\n";
            } else {
                yyerror("Incompatibilidade nao solucionavel: '" + $1.label + "' e " + var.tipo + ", mas recebeu " + $3.tipo);
                YYABORT;
            }
        }
        $$.traducao = $3.traducao + cast_code + "\t" + var.label + " = " + t_src + ";\n";
    }
  }
  ;

SAIDA : TK_PRINT TK_ID ';'
  {
    atributos var = buscaSimbolo($2.label);
    string formato = "%d";
    if (var.tipo == "float") formato = "%f";
    if (var.tipo == "char")  formato = "%c";

    $$.traducao = "\tprintf(\"" + $2.label + " = " + formato + "\\n\", " + var.label + ");\n";
  }
  ;

E : E '+' E { $$ = gerarOperacaoBinaria("+", $1, $3); }
  | E '-' E { $$ = gerarOperacaoBinaria("-", $1, $3); }
  | E '*' E { $$ = gerarOperacaoBinaria("*", $1, $3); }
  | E '/' E { $$ = gerarOperacaoBinaria("/", $1, $3); }
  | '(' E ')' {
      $$.label = $2.label; $$.tipo = $2.tipo; $$.traducao = $2.traducao;
  }
  | '(' TIPO ')' E %prec CAST {
      $$.label = gentempcode();
      $$.tipo = $2.tipo;
      tipo_temp[$$.label] = $$.tipo;
      $$.traducao = $4.traducao + "\t" + $$.label + " = (" + $2.tipo + ") " + $4.label + ";\n";
  }
  | TK_ID {
      atributos var = buscaSimbolo($1.label);
      $$.label = var.label; $$.tipo = var.tipo; $$.traducao = "";
  }
  | TK_NUM {
      $$.label = gentempcode(); $$.tipo = "int"; tipo_temp[$$.label] = $$.tipo;
      $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
  }
  | TK_REAL {
      $$.label = gentempcode(); $$.tipo = "float"; tipo_temp[$$.label] = $$.tipo;
      $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
  }
  | TK_CHAR_VAL {
      $$.label = gentempcode(); $$.tipo = "char"; tipo_temp[$$.label] = $$.tipo;
      $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
  }
  | TK_TRUE {
      $$.label = gentempcode(); $$.tipo = "int"; tipo_temp[$$.label] = $$.tipo;
      $$.traducao = "\t" + $$.label + " = 1;\n";
  }
  | TK_FALSE {
      $$.label = gentempcode(); $$.tipo = "int"; tipo_temp[$$.label] = $$.tipo;
      $$.traducao = "\t" + $$.label + " = 0;\n";
  }
  ;

%%

#include "lex.yy.c"

int yyparse();

string gentempcode()
{
    var_temp_qnt++;
    return "T" + to_string(var_temp_qnt);
}

int main(int argc, char* argv[])
{
    var_temp_qnt = 0;

    if (yyparse() == 0) {
        cout << "===========================================\n";
        cout << "CÓDIGO INTERMEDIÁRIO GERADO:\n";
        cout << "===========================================\n";
        cout << codigo_gerado;

        cout << "\n===========================================\n";
        cout << "TABELA DE SÍMBOLOS (MAPA):\n";
        cout << "===========================================\n";
        for (auto const& [id, temp] : tabela_simbolos) {
            cout << "ID: " << id << " => Temporaria: " << temp << " (" << tipo_temp[temp] << ")" << endl;
        }
    }

    return 0;
}

void yyerror(string MSG)
{
    cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
