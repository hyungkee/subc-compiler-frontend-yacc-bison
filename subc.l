%{
/*
 * File Name   : subc.l
 * Description : a skeleton flex input
 */

#include "subc.h"
#include "subc.tab.h"
static int comment_depth = 0;
static int lineno = 1;
char* f_name = NULL;

%}

/* regular definitions */
letter		[A-Za-z_]
digit		[0-9]
id		{letter}({letter}|{digit})*
integer_const	([1-9]{digit}*)|"0"
white-space		[ \t]+
special-char	\\[nt]
single-return	","|";"|"("|")"|"="|"{"|"}"|"+"|"-"|"*"|"/"|"%"|"&"|"|"|"!"|"["|"]"|"."


%x COMMENT
%%
{id}	{
		   yylval.idPtr = enter(ID, yytext, yyleng);
		   return yylval.idPtr->lextype;
		}

{integer_const}	{
		   yylval.intVal = atoi(yytext);
		   return INTEGER_CONST;
		}

\"({special-char}|[^\\\"\n])*\"	{
			/* String Variable */
		   yylval.stringVal = malloc(sizeof(char)*yyleng);
		   strcpy(yylval.stringVal, yytext);
		   return STRING;
		}
'({special-char}|[^\\'\n])'|''	{
			/* Character Variable */
		   yylval.stringVal = malloc(sizeof(char)*yyleng);
		   strcpy(yylval.stringVal, yytext);
		   return CHAR_CONST;
		}
{single-return}	{ return yytext[0]; }

"+="|"-="|"*="|"/="|"%="	{
	yylval.stringVal = malloc(sizeof(char)*yyleng);
	strcpy(yylval.stringVal, yytext);
	return ASSIGNOP;
}
"||"	{
	return LOGICAL_OR;
}
"&&"	{
	return LOGICAL_AND;
}
"<"|"<="|">"|">="	{
	yylval.stringVal = malloc(sizeof(char)*yyleng);
	strcpy(yylval.stringVal, yytext);
	return RELOP;
}
"=="|"!="	{
	yylval.stringVal = malloc(sizeof(char)*yyleng);
	strcpy(yylval.stringVal, yytext);
	return EQUOP;
}
"++"	{
	return INCOP;
}
"--"	{
	return DECOP;
}
"->"	return STRUCTOP;

\/\/.*\n { /* comment */ ++lineno; }

{white-space}

<*>\n		   ++lineno;

<INITIAL,COMMENT>"/*"	{
		   ++comment_depth;
		   BEGIN (COMMENT);
		}
<COMMENT>"*/"	   if(--comment_depth == 0) BEGIN (INITIAL);
<COMMENT>.		 {}


%%

int read_line()
{
   return lineno;
}

char* get_file_name()
{
	return f_name;
}

void init_type()
{

	inttype = maketypedecl(INT);
	chartype = maketypedecl(CHAR);
	voidtype = maketypedecl(VOID);

	declare(hash_lookup("int"), inttype);
	declare(hash_lookup("char"), chartype);
	declare(hash_lookup("void"), voidtype);

	returnid = enter(ID, "*return", 7);

}

void init_code_generation(){
	fprintf(fout, "    push_const EXIT\n");
	fprintf(fout, "    push_reg fp\n");
	fprintf(fout, "    push_reg sp\n");
	fprintf(fout, "    pop_reg fp\n");
	fprintf(fout, "    jump main\n");
	fprintf(fout, "EXIT:\n");
	fprintf(fout, "    exit\n");
}
   
int main(int argc, char* argv[])
{
	f_name = argv[1];
 // we can recognize other tokens using id lexer
   static char *keyword[] = { "int","char", "void", "struct", "return", "if", "else", "while", "for", "break", "continue", "read_int", "read_char", "write_int", "write_string", "write_char", NULL };
   static int tokentype[] = { TYPE, TYPE, VOID, STRUCT, RETURN, IF, ELSE, WHILE, FOR, BREAK, CONTINUE, RINT, RCHAR, WINT, WSTRING, WCHAR, 0 };
   int i;
   for(i = 0; keyword[i] != NULL; i++)
      enter(tokentype[i], keyword[i], strlen(keyword[i]));

   fout_temp = fopen("temp", "w");

   if(argc >= 2)
	yyin = fopen(argv[1], "r");
   else
	yyin = stdin;

   if(argc >= 3)
	fout_file = fopen(argv[2], "w");
   else
	fout_file = fopen("subc.s", "w");
   fout = fout_file;

   if(!yyin) {
      printf("Can't open input stream!\n");
      exit(1);
   }

   init_code_generation();
   push_scope(0);
   set_global_scope();
   init_type();


   yyparse();

   fprintf(fout, "Lglob.    data %d\n", global->counter);

   fclose(yyin);
   return 0;
}
