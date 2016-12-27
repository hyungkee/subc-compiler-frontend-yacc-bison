%{
/*
 * File Name   : subc.y
 * Description : a skeleton bison input
 */ 

#include "subc.h"

int    yylex ();
int    yyerror (char* s);

void print_error(char* s);
%}

/* yylval types */
%union{
	int		 intVal;
	double		 floatVal;
	char		*stringVal;
	struct id	*idPtr;
	struct decl	*declPtr;
	struct ste	*stePtr;
	struct laVal	labelVal;
}


/* Precedences and Associativities */


%left	','
%right ASSIGNOP '='
%left LOGICAL_OR
%left LOGICAL_AND
%left '&'
%left EQUOP
%left RELOP
%left '+' '-'
%left '*' '/' '%'
%right '!' INCOP DECOP
%left 	'[' ']' '(' ')' '.' STRUCTOP
%nonassoc STARPTR


%nonassoc IFX
%nonassoc ELSE


/* Token and Types */
%token 	STRUCT RETURN IF ELSE BREAK CONTINUE LOGICAL_OR LOGICAL_AND INCOP DECOP RINT RCHAR WINT WSTRING WCHAR
%token<labelVal>	WHILE FOR
%token<stringVal>	STRUCTOP ASSIGNOP RELOP EQUOP

%token<idPtr>		ID INT CHAR TYPE VOID
%token<intVal>		INTEGER_CONST
%token<stringVal>	CHAR_CONST STRING

%type<declPtr>		type_specifier struct_specifier unary binary expr expr_e or_expr or_list and_expr and_list const_expr args func_decl
%type<intVal>		pointers if_head
%%

program
		: ext_def_list
		;

ext_def_list
		: ext_def_list ext_def
		| /* empty */
		;

ext_def
		: type_specifier pointers ID ';'			{ declare($3, makevardecl(makepointerdecl($2, $1))); }
		| type_specifier pointers ID '[' const_expr ']' ';'	{ declare($3, makeconstdecl(makearraydecl($5, makevardecl(makepointerdecl($2, $1))))); }
		| func_decl ';' { if($1->defined != 0){print_error("function redeclaration");} else{$1->defined = 1;}}
		| type_specifier ';'
		| func_decl
				{
					if($1->defined == 2){print_error("function redeclaration");}
					push_scope($1->size+1);
					pushstelist($1->formals);
					fprintf(fout,"%s:\n", find_id($1)->name);
				}
		  func_compound_stmt
				{
					remove_scope(pop_scope());
					$1->defined = 2;
					fprintf(fout,"%s_final:\n", find_id($1)->name);
					fprintf(fout, "    push_reg fp\n");
					fprintf(fout, "    pop_reg sp\n");
					fprintf(fout, "    pop_reg fp\n");
					fprintf(fout, "    pop_reg pc\n");
					fprintf(fout,"%s_end:\n", find_id($1)->name);
				}

type_specifier
		: TYPE			{ $$ = lookup($1); } 
		| VOID			{ $$ = voidtype; }
		| struct_specifier	{ $$ = $1; }

struct_specifier 
		: STRUCT ID '{' { push_scope(0); } def_list '}'	{ check_struct_new($2); declare($2, $$ = makestructdecl(regist_struct(pop_scope()))); }	
		| STRUCT ID					{ check_isstruct( $$ = lookup_struct($2), "incomplete type error"); } 

func_decl
		: type_specifier pointers ID '(' ')'
		{
			struct decl *procdecl = makeprocdecl();
			procdecl = declare_function($3, procdecl);
			push_scope(1); /* for collecting formals */
			declare(returnid, makepointerdecl($2, $1));

			struct ste *formals;
			formals = pop_scope();
			/* popscope reverses stes (first one is the returnid) */
			insert_function_formals(procdecl, formals);
			$$ = procdecl;
		}

		| type_specifier pointers ID '(' VOID ')' 
		{
			struct decl *procdecl = makeprocdecl();
			procdecl = declare_function($3, procdecl);
			push_scope(1); /* for collecting formals */
			declare(returnid, makepointerdecl($2, $1));

			struct ste *formals;
			formals = pop_scope();
			/* popscope reverses stes (first one is the returnid) */
			insert_function_formals(procdecl, formals);
			$$ = procdecl;
		}

		| type_specifier pointers ID '(' {
			struct decl *procdecl = makeprocdecl();
			procdecl = declare_function($3, procdecl);
			push_scope(1); /* for collecting formals */
			declare(returnid, makepointerdecl($2, $1));
			$<declPtr>$ = procdecl;
		}
		param_list ')' 
		{
			struct ste *formals;
			struct decl *procdecl = $<declPtr>5;
			formals = pop_scope();
			/* popscope reverses stes (first one is the returnid) */
			insert_function_formals(procdecl, formals);
			$$ = procdecl;
		}

pointers
		: '*'			{ $$ = 1; }
		| /* empty */		{ $$ = 0; }

param_list  /* list of formal parameter declaration */
		: param_decl
		| param_list ',' param_decl

param_decl  /* formal parameter declaration */
		: type_specifier pointers ID				{ declare($3, makevardecl(makepointerdecl($2, $1))); }
		| type_specifier pointers ID '[' const_expr ']'		{ declare($3, makeconstdecl(makearraydecl($5, makevardecl(makepointerdecl($2, $1))))); }

def_list    /* list of definitions, definition can be type(struct), variable, function */
		: def_list def
		| /* empty */

def
		: type_specifier pointers ID ';'			{ declare($3, makevardecl(makepointerdecl($2, $1)));}
		| type_specifier pointers ID '[' const_expr ']' ';'	{ declare($3, makeconstdecl(makearraydecl($5, makevardecl(makepointerdecl($2, $1))))); }
		| type_specifier ';'
		| func_decl ';'

func_compound_stmt
		: '{' local_defs
			{
				int cnt = get_scope_size();
				if(cnt > 0)
					fprintf(fout, "    shift_sp %d\n", cnt);
				fprintf(fout, "%s_start:\n", find_id(lookup_func())->name);
			}
		  stmt_list '}' 

compound_stmt
		: '{' local_defs
			{
				int cnt = get_scope_size();
				if(cnt > 0)
					fprintf(fout, "    shift_sp %d\n", cnt);
			}
		  stmt_list '}' 
			{
				int cnt = get_scope_size();
				if(cnt > 0)
					fprintf(fout, "    shift_sp -%d\n", cnt);
			}

local_defs  /* local definitions, of which scope is only inside of compound statement */
		:	def_list

stmt_list
		: stmt_list stmt
		| /* empty */

if_head		: IF '(' expr ')'	{ // Label For ELSE ( in single IF, it's ESCAPE)
						$$ = labelcounter;
						labelcounter++;
						fprintf(fout,"    branch_false label_%d\n",$$);
					}

stmt
		: expr ';'		{ fprintf(fout, "    shift_sp -%d\n", $1->size);}
		| { push_scope(get_scope_counter()); } compound_stmt { remove_scope(pop_scope()); }
		| RETURN ';'		{
						fprintf(fout, "    jump %s_final\n", find_id(lookup_func())->name);
					 	check_compatible_type(lookup_func()->returntype, voidtype, "return value is not return type"); 
					}
		| RETURN 		{
						$<intVal>$ = strcmp(find_id(lookup_func())->name, "main");
						if($<intVal>$ != 0){ // is not a main
							fprintf(fout,"    push_reg fp\n");
							fprintf(fout,"    push_const -1\n");
							fprintf(fout,"    add\n");  // return address
							fprintf(fout,"    push_const -%d\n", lookup_func()->returntype->size);
							fprintf(fout,"    add\n");  // return value
						}
					}
		  expr ';'
					{
						if($<intVal>$ != 0){ // is not a main
							load_assign(lookup_func()->returntype, $3);
						}
						fprintf(fout, "    jump %s_final\n", find_id(lookup_func())->name);
					 	check_compatible_type(lookup_func()->returntype, $3->type, "return value is not return type"); 
					}
		| ';'
		| if_head stmt 	%prec IFX{ // can avoid critical conflict
						fprintf(fout,"label_%d:\n",$1); // mark ESCAPE label
//						check_compatible_type($3, inttype, "not int type");
					}	

		| if_head stmt ELSE 	{ // Label For ESCAPE
						$<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"    jump label_%d\n",$<intVal>$); // go to ESCAPE label
						fprintf(fout,"label_%d:\n",$1); // mark ELSE label
//						check_compatible_type($3, inttype, "not int type");
					}
		 stmt 			{
						fprintf(fout,"label_%d:\n",$<intVal>4); // mark ESCAPE label
//						check_compatible_type($3, inttype, "not int type");
					}

		| WHILE			{ // Label For WHILE
						// Label Backup
						$1.start_label = start_label;
						$1.escape_label = escape_label;
						start_label = $<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"label_%d:\n",$<intVal>$); // mark WHILE label
					}
		  '(' expr ')' 		{ // Label For ESCAPE
						escape_label = $<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"    branch_false label_%d\n",$<intVal>$);
						check_compatible_type($4->type, inttype, "not int type");
					}
		  stmt			{
						fprintf(fout,"    jump label_%d\n",$<intVal>2); // go to WHILE label
						fprintf(fout,"label_%d:\n",$<intVal>6); // mark ESCAPE label
						// Label Recover
						start_label = $1.start_label;
						escape_label = $1.escape_label;
					}

		| FOR '(' expr_e ';' 	{ // Label For FOR
						// Label Backup
						$1.start_label = start_label;
						$1.escape_label = escape_label;
						// pop one element ( disposit )
						fprintf(fout, "    shift_sp -%d\n", $3->size);
						// Label For FOR
						start_label = $<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"label_%d:\n",$<intVal>$); // mark FOR label
					}
		 expr_e ';'		{ // Label For ESCAPE
						escape_label = $<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"    branch_false label_%d\n",$<intVal>$);
					}
					{ // Label For STMT
						$<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"    jump label_%d\n",$<intVal>$); // go to STMT label
					}
					{ // Label For ITER_EXPR
						$<intVal>$ = labelcounter;
						labelcounter++;
						fprintf(fout,"label_%d:\n",$<intVal>$); // mark ITER_EXPR label
					}
		 expr_e ')'		{ // Before STMT, After ITER_EXPR
						// pop one element ( disposit )
						fprintf(fout, "    shift_sp -1\n");

						fprintf(fout,"    jump label_%d\n",$<intVal>5); // go to FOR label
						fprintf(fout,"label_%d:\n",$<intVal>9); // mark STMT label
					}
		 stmt			{
						fprintf(fout,"    jump label_%d\n",$<intVal>10); // go to ITER_EXPR label
						fprintf(fout,"label_%d:\n",$<intVal>8); // mark ESCAPE label
						// Label Recover
						start_label = $1.start_label;
						escape_label = $1.escape_label;
					}
		| BREAK ';'		{
						int cnt = get_scope_size();
						if(cnt > 0)
							fprintf(fout, "    shift_sp -%d\n", cnt);
						fprintf(fout, "    jump label_%d\n", escape_label);
					}
		| CONTINUE ';'		{
						int cnt = get_scope_size();
						if(cnt > 0)
							fprintf(fout, "    shift_sp -%d\n", cnt);
						fprintf(fout, "    jump label_%d\n", start_label);
					}
		| RINT '(' unary ')' ';'	{
							load_fetch($3,-1); // address
							fprintf(fout,"    read_int\n");
							fprintf(fout,"    assign\n");
						}
		| RCHAR '(' unary ')' ';'	{
							load_fetch($3,-1); // address
							fprintf(fout,"    read_char\n");
							fprintf(fout,"    assign\n");
						}
		| WINT '(' expr ')' ';'		{
							load_fetch($3,0); // value
							fprintf(fout,"    write_int\n");
						}
		| WCHAR '(' expr ')' ';'	{
							load_fetch($3,0); // value
							fprintf(fout,"    write_char\n");
						}
		| WSTRING '(' expr ')' ';'	{
							load_fetch($3,-1); // address
							fprintf(fout,"    write_string\n");
						}


expr_e
		: expr				{ $$ = $1; }
		| /* empty */			{ $$ = makeconstdecl(inttype); fprintf(fout,"    push_const 1\n"); }

const_expr
		: {fout = fout_temp;}
		  expr
		  { $$ = $2; fout = fout_file; } /* if it's expr, it may lose integer value. */

expr
		: unary {
				load_fetch($1,-1); // address(unary)
				fprintf(fout,"    push_reg sp\n");
				fprintf(fout,"    fetch\n"); // copy address
			}
		  '=' expr
			{
				load_fetch($4,0); // value(expr)

				load_assign($1->type,$4); // assign

				load_fetch($1,0); // make LHS's address to value
				$$ = clonedecl($1);
			}
		| or_expr			{ $$ = $1; }


or_expr
		: or_list			{ $$ = $1; }

or_list
		: or_list LOGICAL_OR and_expr	{ $$ = $1;
						  check_compatible_type($1->type, inttype, "not int type");
						  check_compatible_type($3->type, inttype, "not int type");
						  fprintf(fout,"    or\n");
						}
		| and_expr			{ $$ = $1; }

and_expr
		: and_list			{ $$ = $1; }

and_list
		: and_list LOGICAL_AND binary	{ $$ = $1;
						  check_compatible_type($1->type, inttype, "not int type");
						  check_compatible_type($3->type, inttype, "not int type");
						  fprintf(fout,"    and\n");
						}
		| binary			{ $$ = $1; }

binary
		: binary RELOP binary		{
						  $$ = makeconstdecl(inttype);
						  check_compatible_type_OP($1->type, $3->type, "not comparable"); 
						  BinaryOperation($2);
						}
		| binary EQUOP binary		{
						  $$ = makeconstdecl(inttype);
						  check_compatible_type_OP($1->type, $3->type, "not comparable"); 
						  BinaryOperation($2);
						}
		| binary '+' binary		{
						  if($1!=NULL && $1->type->typeclass == 3){ // ptr + int
						  	fprintf(fout,"    push_const %d\n", $1->type->ptrto->size);
						  	fprintf(fout,"    mul\n");
							fprintf(fout,"    add\n"); 
							$$ = clonedecl($1);
						  }
						  else if($3!=NULL && $3->type->typeclass == 3){ // int + ptr
						  	fprintf(fout,"    push_reg sp\n");
						  	fprintf(fout,"    push_const 1\n");
							fprintf(fout,"    sub\n");
							fprintf(fout,"    fetch\n"); // it's first binary's value
						  	fprintf(fout,"    push_const %d\n", $3->type->ptrto->size - 1);
						  	fprintf(fout,"    mul\n");
							fprintf(fout,"    add\n"); 
							fprintf(fout,"    add\n"); // add twice
							$$ = clonedecl($3);
						  }
						  else{ // int + int
							$$ = clonedecl($1);
							fprintf(fout,"    add\n"); 
						  }
						  $$->value = $1->value + $3->value;
						}
		| binary '-' binary		{
						  $$ = clonedecl($1);
						  if($1!=NULL && $1->type->typeclass == 3){
						  	fprintf(fout,"    push_const %d\n", $1->type->ptrto->size);
						  	fprintf(fout,"    mul\n");
						  }
						  $$->value = $1->value - $3->value;
						  fprintf(fout,"    sub\n"); 
						}
		| binary '*' binary		{
						  $$ = clonedecl($1);
						  $$->value = $1->value * $3->value;
						  fprintf(fout,"    mul\n"); 
						}
		| binary '/' binary		{
						  $$ = clonedecl($1);
						  $$->value = $1->value / $3->value;
						  fprintf(fout,"    div\n");
						}
		| binary '%' binary		{
						  $$ = clonedecl($1);
						  $$->value = $1->value % $3->value;
						  fprintf(fout,"    mod\n"); 
						}
		| unary %prec '='		{
							load_fetch($1,0);
							$$ = $1;
						}

unary
		: '(' expr ')'			{ $$ = $2; }
		| '(' unary ')' 		{ $$ = $2; }
		| INTEGER_CONST			{ $$ = makeconstdecl_int($1); fprintf(fout,"    push_const %d\n", $1);}
		| CHAR_CONST			{
							$$ = makeconstdecl_char($1);
							fprintf(fout,"    push_const %d\n",$1[1]);
						}
		| STRING			{
							$$ = addpointerdecl(makeconstdecl_char($1));
							fprintf(fout,"str_%d.  string %s\n",strcounter,$1);
							fprintf(fout,"    push_const str_%d\n",strcounter);
							strcounter++;
						}	// it's pointer of first character
		| ID				{
							$$ = clonedecl(lookup($1));
							if($$ != NULL && $$->type != NULL && $$->type->typeclass == 2)
								$$->size = 1; // first, it's const ( a kind of ptr)
							if($$==NULL)	print_error("not declared");
							load_var($$); // address
 						}
		| '-' unary	%prec '!'	{ 
							$$ = $2;
							check_compatible_type($2->type, inttype, "not int type");
							load_fetch($2, 0); // fetching(value)
							fprintf(fout,"    negate\n");
						}
		| '!' unary			{
						 	$$ = $2; 
							check_compatible_type($2->type, inttype, "not int type"); 
							load_fetch($2, 0); // fetching(value)
							fprintf(fout,"    not\n");
						}
		| unary INCOP			{
							$$ = $1; check_isvar($1, "not declared");
							check_can_inc($1);
							int size = 1;
							if($1->type!=NULL && $1->type->typeclass == 3) // it's ptr
								size = $1->type->ptrto->size;
							load_fetch($1, -1); // fetching(address)
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    fetch\n"); // fetching(value)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    add\n");
							fprintf(fout,"    assign\n");
							load_fetch($1, 0); // fetching(address)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    sub\n");
						}
		| unary DECOP			{
							$$ = $1; check_isvar($1, "not declared");
							check_can_inc($1);
							int size = 1;
							if($1->type!=NULL && $1->type->typeclass == 3) // it's ptr
								size = $1->type->ptrto->size;
							load_fetch($1, -1); // fetching(address)
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    fetch\n"); // fetching(value)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    sub\n");
							fprintf(fout,"    assign\n");
							load_fetch($1, 0); // fetching(address)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    add\n");
						}
		| INCOP unary			{
							$$ = $2; check_isvar($2, "not declared");
							check_can_inc($2);
							int size = 1;
							if($2->type!=NULL && $2->type->typeclass == 3) // it's ptr
								size = $2->type->ptrto->size;
							load_fetch($2, -1); // fetching(address)
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    fetch\n"); // fetching(value)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    add\n");
							fprintf(fout,"    assign\n");
						}
		| DECOP unary			{
							$$ = $2; check_isvar($2, "not declared");
							check_can_inc($2);
							int size = 1;
							if($2->type!=NULL && $2->type->typeclass == 3) // it's ptr
								size = $2->type->ptrto->size;
							load_fetch($2, -1); // fetching(address)
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    fetch\n");
							fprintf(fout,"    fetch\n"); // fetching(value)
							fprintf(fout,"    push_const %d\n",size);
							fprintf(fout,"    sub\n");
							fprintf(fout,"    assign\n");
						}
		| '&' unary	%prec '!'	{
							$$ = addpointerdecl($2);
							check_isvar($2, "not declared");
						}
		| '*' unary	%prec STARPTR  {
							$$ = removepointerdecl($2);
						}
		| unary '['			{
							if($1->type != NULL && $1->type->typeclass == 2) // array
								load_fetch($1, -1); // fetching(address)
							if($1->type != NULL && $1->type->typeclass == 3) // ptr
								load_fetch($1, 0); // fetching(value)
						}
		  expr ']'			{
							$$ = arrayaccess($1, $4->type);
							if($$->size > 1){
								fprintf(fout,"    push_const %d\n", $$->size);
								fprintf(fout,"    mul\n");
							}
							fprintf(fout,"    add\n");
						}
		| unary '.' ID			{
							load_fetch($1, -1); // fetching(address)
							$$ = structaccess($1, $3);
							load_fetch($$, -1); // fetching(address)
							if($$->offset > 0){
								fprintf(fout,"    push_const %d\n", $$->offset);
								fprintf(fout,"    add\n");
							}
						}
		| unary STRUCTOP ID		{
							load_fetch($1, 0); // fetching(value) : value is a kind of pointer
							$$ = structaccess(removepointerdecl($1), $3);
							load_fetch($$, -1); // fetching(address)
							if($$->offset > 0){
								fprintf(fout,"    push_const %d\n", $$->offset);
								fprintf(fout,"    add\n");
							}
						}
		| unary '(' 			{
							$<declPtr>$ = NULL;
							fprintf(fout,"    shift_sp %d\n", $1->returntype->size); // return value
							fprintf(fout,"    push_const label_%d\n",labelcounter); // return address
							fprintf(fout,"    push_reg fp\n"); // fp
							
							// add actuals in args
						}
		 args ')'			{
							$$ = clonedecl($1);
							$$->size = $1->returntype->size;

							check_isproc($1, "not declared");
							checkfunctioncall($1, $4); 

							int cnt = 0;
							struct decl* actuals = $4;
							while(actuals != NULL) {
								if(actuals->typeclass == 2)
									cnt+=1;
								else
									cnt+=actuals->size;
								actuals = actuals->next;
							}
							// set fp
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    push_const -%d\n", cnt);
							fprintf(fout,"    add\n");
							fprintf(fout,"    pop_reg fp\n");

							fprintf(fout,"    jump %s\n", find_id($1)->name); // return address
							fprintf(fout,"label_%d:\n",labelcounter); // return address
							labelcounter++;
						}
		| unary '(' ')'			{
							$$ = clonedecl($1);
							$$->size = $1->returntype->size;

							check_isproc($1, "not declared");
							checkfunctioncall($1, NULL); 

							fprintf(fout,"    shift_sp %d\n", $1->returntype->size); // return value
							fprintf(fout,"    push_const label_%d\n",labelcounter); // return address
							fprintf(fout,"    push_reg fp\n"); // fp

							// set fp
							fprintf(fout,"    push_reg sp\n");
							fprintf(fout,"    pop_reg fp\n");

							fprintf(fout,"    jump %s\n", find_id($1)->name); // return address
							fprintf(fout,"label_%d:\n",labelcounter); // return address
							labelcounter++;
						}

args    /* actual parameters(function arguments) transferred to function */
		: expr				{ $$ = clonedecl($1->type);}
		| args ',' expr			{ $$ = addtypedecl($1, clonedecl($3->type)); }

%%

/*  Additional C Codes 
 	Implemnt REDUCE function here */

void BinaryOperation(char* str){
	if(strcmp(str, ">") == 0){
		fprintf(fout,"    greater\n");
	}
	if(strcmp(str, ">=") == 0){
		fprintf(fout,"    greater_equal\n");
	}
	if(strcmp(str, "<") == 0){
		fprintf(fout,"    less\n");
	}
	if(strcmp(str, "<=") == 0){
		fprintf(fout,"    less_equal\n");
	}
	if(strcmp(str, "==") == 0){
		fprintf(fout,"    equal\n");
	}
	if(strcmp(str, "!=") == 0){
		fprintf(fout,"    not_equal\n");
	}
}


void load_assign(struct decl* type, struct decl* decl){

	if(type!=NULL && type->typeclass == 4){ // struct
		int i;
		for(i=0;i<type->size;i++){
			fprintf(fout,"    push_reg sp\n");
			fprintf(fout,"    push_const %d\n", type->size-i);
			fprintf(fout,"    sub\n");
			fprintf(fout,"    fetch\n"); // it's LHS's address
			fprintf(fout,"    push_const %d\n", type->size-i-1);
			fprintf(fout,"    add\n");

			fprintf(fout,"    push_reg sp\n");
			fprintf(fout,"    push_const 1\n");
			fprintf(fout,"    sub\n");
			fprintf(fout,"    fetch\n"); // it's RHS's i-th value

			fprintf(fout,"    assign\n");
			fprintf(fout,"    shift_sp -1\n");
		}
		fprintf(fout,"    shift_sp -1\n"); // remove LHS's address
	}else{
		fprintf(fout,"    assign\n");
	}

}


void load_var(struct decl* decl){
	if(decl->declclass == 0 || (decl->declclass == 1 && decl->type->typeclass == 2)){ // int or const(array)
//		fprintf(fout,"-----load %s----------\n", find_id(decl)->name);
		if(decl->isglobal){
			fprintf(fout,"    push_const Lglob+%d\n",decl->offset);
		} else {
			fprintf(fout,"    push_reg fp\n");
			fprintf(fout,"    push_const %d\n", decl->offset);
			fprintf(fout,"    add\n");
		}
	}
}

void load_fetch(struct decl* decl, int os){
	if(decl!=NULL){
		int i;


		if(decl->type != NULL && decl->type->typeclass == 4 && os == 0){ // struct value
			if(decl->ptrcoef+os>0){
				// address of struct start
				for(i=0;i<decl->ptrcoef+os-1;i++)
					fprintf(fout,"    fetch\n");

				fprintf(fout,"    shift_sp %d\n", decl->size); // alloc one more byte
				fprintf(fout,"    push_reg sp\n");
				fprintf(fout,"    push_const %d\n", decl->size);
				fprintf(fout,"    sub\n");
				fprintf(fout,"    fetch\n"); // copy struct start address.

				fprintf(fout,"    shift_sp -%d\n", decl->size+2); // go for over write

				for(i=0;i<decl->size;i++){
					fprintf(fout,"    push_reg sp\n");
					fprintf(fout,"    push_const %d\n", decl->size-i+2);
					fprintf(fout,"    add\n");
					fprintf(fout,"    fetch\n"); // address of struct start

					fprintf(fout,"    push_const %d\n", i);
					fprintf(fout,"    add\n");
					fprintf(fout,"    fetch\n"); // value of struct[i]
				}
			}
		}else{
			// address of var start
			for(i=0;i<decl->ptrcoef+os;i++)
				fprintf(fout,"    fetch\n");
		}

		decl->ptrcoef = -os;
	}
}


int check_same_trans_var(struct decl* decl1, struct decl* decl2){
	if(decl1 == NULL || decl2 == NULL)
		return 0;
	if(decl1->origin != decl2->origin)
		return 0;

	struct decl* type1 = decl1->type;
	struct decl* type2 = decl2->type;

	int leng1 = 0;
	int leng2 = 0;

	while(type1 != NULL && type1 -> typeclass == 3){ // ptr
		type1 = type1->ptrto;
		leng1++;
	}
	while(type2 != NULL && type2 -> typeclass == 3){ // ptr
		type2 = type2->ptrto;
		leng2++;
	}

	return leng1+decl1->ptrcoef == leng2+decl2->ptrcoef;
	
}


void pushstelist(struct ste* ste){
	while(ste != NULL){
		insert(ste->name, ste->decl);
		ste = ste->prev;
	}
}

struct decl* typevalue(struct decl* decl){
	if(decl == NULL)
		return NULL;

// VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	if(decl->declclass == 2)
		return decl->returntype;
	else
		return decl->type;
}

struct decl* clonedecl(struct decl* decl)
{
	if(decl == NULL)
		return NULL;

	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	*new_decl = *decl; // copy
//	new_decl->type = clonedecl(decl->type);
//	new_decl->ptrto = clonedecl(decl->ptrto);
	return new_decl;
}

struct decl* addtypedecl(struct decl* decl1, struct decl* decl2)
{
	struct decl* decl = decl1;
	while(decl->next != NULL)	decl = decl->next;
	decl->next = decl2;
	return decl1;
}

struct decl* makeprocdecl(){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 2; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->defined = 0;
	new_decl->origin = new_decl;
	return new_decl;
}

struct decl* maketypedecl(int type){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->size = 1;
	new_decl->origin = new_decl;
	new_decl->declclass = 3; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	if(type == INT)
	new_decl->typeclass = 0; // int : 0, char : 1, array : 2, ptr : 3, struct : 4
	if(type == CHAR)
	new_decl->typeclass = 1;
	if(type == VOID)
	new_decl->typeclass = 5; // VOID!

	return new_decl;
}

struct decl* makestructdecl(struct ste* ste){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 3; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->typeclass = 4; // int : 0, char : 1, array : 2, ptr : 3, struct : 4
	new_decl->fieldlist = ste;
	new_decl->origin = new_decl;

	while(ste != NULL){
		struct decl* decl = ste->decl;
		if(decl->declclass == 0 || (decl->declclass == 1 && decl->type->typeclass == 2)){ // var or const(array)
//			printf("?? of %s : %d\n", ste->name->name, ste->decl->size);
			new_decl->size += decl->size;
		}
		ste = ste->prev;
	}

	return new_decl;
}


struct decl* makeconstdecl(struct decl* decl1){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 1; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->type = decl1;
	new_decl->size = decl1->size;
	new_decl->origin = new_decl;

	return new_decl;
}

struct decl* makeconstdecl_int(int int_value){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 1; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->type = inttype;
	new_decl->value = int_value;
	new_decl->size = 1;
	new_decl->origin = new_decl;

	return new_decl;
}

struct decl* makeconstdecl_char(char *char_value){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 1; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->type = chartype;
	new_decl->char_value = char_value;
	new_decl->size = 1;
	new_decl->origin = new_decl;

	return new_decl;
}

struct decl* makevardecl(struct decl* decl1){
	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 0; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->type = decl1;
	new_decl->size = decl1->size;
	new_decl->ptrcoef = 1;
	new_decl->origin = new_decl;


	return new_decl;
}

struct decl* makepointerdecl(int cnt, struct decl* decl1){
	struct decl* top = decl1;

	if(decl1!=NULL)	top->size = decl1->size;
	int i;

	for(i=0;i<cnt;i++){
		struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
		new_decl->declclass = 3; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
		new_decl->typeclass = 3; // int : 0, char : 1, array : 2, ptr : 3, struct : 4
		new_decl->ptrto = top;
		new_decl->size = 1;
		top = new_decl;
	}

	top->origin = top;
	return top;
}


struct decl* makearraydecl(struct decl* decl1, struct decl* decl2){

	struct decl* new_decl = (struct decl*) malloc(sizeof(struct decl));
	new_decl->declclass = 3; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	new_decl->typeclass = 2; // int : 0, char : 1, array : 2, ptr : 3, struct : 4
	new_decl->origin = new_decl;
	new_decl->num_index = decl1->value;
	check_compatible_type(decl1, inttype, "not int type");
	new_decl->elementvar = decl2;
	new_decl->size = new_decl->num_index * new_decl->elementvar->size;

	return new_decl;
}

struct decl* addpointerdecl(struct decl* decl1){
	// create const decl
	struct decl* decl = (struct decl*) malloc(sizeof(struct decl));
	decl->declclass = 1; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	decl->origin = decl1->origin;
	decl->ptrcoef = decl1->ptrcoef - 1;

	// add pointer
	struct decl* ptr = (struct decl*) malloc(sizeof(struct decl));
	ptr->declclass = 3; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	ptr->typeclass = 3; // int : 0, char : 1, array : 2, ptr : 3, struct : 4
	ptr->size = 1;

	// connect
	if(decl1 != NULL)	ptr->ptrto = decl1->type;
	decl->type = ptr;

	return decl;
}

struct decl* removepointerdecl(struct decl* decl1){
	// create var decl
	struct decl* decl = (struct decl*) malloc(sizeof(struct decl));
	decl->declclass = 0; // VAR : 0, CONST : 1, FUNC : 2, TYPE : 3
	if(decl1 != NULL){
		decl->origin = decl1->origin;
		decl->ptrcoef = decl1->ptrcoef + 1;
	}

	// find next type
	struct decl* type = NULL;
	if(decl1 != NULL)	type = decl1->type;
	if(type != NULL){
		if(type->declclass == 3 && type->typeclass == 3) // ptr
			type = type->ptrto;
		else if(type->declclass == 3 && type->typeclass == 2) // array
			type = type->elementvar->type;
		else
			print_error("it's not a pointer type!");
		decl->size = type->size;
	}

	// connect
	decl->type = type;

	return decl;
}



void check_can_inc(struct decl* var)
{
	if(var!=NULL && var->declclass == 0){
		if(var->typeclass == 0 || var->typeclass == 1 || var->typeclass == 3 )	// int, char, ptr can ++
			return;
		print_error("not int, char or pointer");
	}
	 
	print_error("not variable");
}

void check_struct_new(struct id* id)
{
	struct ste* ste = top->ste;
	while(ste != NULL){
		if(ste->name == id){
			print_error("redeclaration");
			return;
		}
		ste = ste->prev;
	}
}

void check_isvar(struct decl* var, char* error_message){
	if(var != NULL && var->declclass == 0)
		return;
	if(error_message != NULL)
		print_error(error_message);
}

void check_isproc(struct decl* proc, char* error_message)
{
// NULL protection
	if(proc != NULL){
		if(proc->declclass != 2) // is not proc
			print_error("not a function");
		return;
	}
// it's null : could't find proc before
	if(error_message != NULL)
		print_error(error_message);
}


struct decl *check_compatible_type(struct decl* type1, struct decl* type2, char* error_message)
{
	int ptrcnt = 0;

	while(type1 != NULL && type2 != NULL){
		if((type1 -> typeclass == 2 || type1 -> typeclass == 3) && (type2 -> typeclass == 2 || type2 -> typeclass == 3)){
			ptrcnt++;
			// both pointer or array
			if(type1 -> typeclass == 2) // array
				type1 = type1->elementvar->type;
			else if(type1 -> typeclass == 3) // ptr
				type1 = type1->ptrto;
			if(type2 -> typeclass == 2) // array
				type2 = type2->elementvar->type;
			else if(type2 -> typeclass == 3) // ptr
				type2 = type2->ptrto;
			continue;
		} else 	if(type1->typeclass == type2->typeclass){
			return type1;
		}
		break;
	}

	if(error_message != NULL)
		print_error(error_message);
	return NULL;
}

struct decl *check_compatible_type_OP(struct decl* type1, struct decl* type2, char* error_message)
{
	int ptrcnt = 0;

	while(type1 != NULL && type2 != NULL){
		if((type1 -> typeclass == 2 || type1 -> typeclass == 3) && (type2 -> typeclass == 2 || type2 -> typeclass == 3)){
			ptrcnt++;
			// both pointer or array
			if(type1 -> typeclass == 2) // array
				type1 = type1->elementvar->type;
			else if(type1 -> typeclass == 3) // ptr
				type1 = type1->ptrto;
			if(type2 -> typeclass == 2) // array
				type2 = type2->elementvar->type;
			else if(type2 -> typeclass == 3) // ptr
				type2 = type2->ptrto;
			continue;
		} else{
			if(ptrcnt>0 && type1->typeclass == type2->typeclass)	// pointer!(it don't mind void pointer or struct pointer)
				return type1;
			if(type1->typeclass == 0 && type2->typeclass == 0) // int
				return type1;
			if(type1->typeclass == 1 && type2->typeclass == 1) // char
				return type1;
		}
		break;
	}

	if(error_message != NULL)
		print_error(error_message);
	return NULL;
}

struct decl *plusdecl(struct decl* decl1, struct decl* decl2)
{
	struct decl *after = decl1;
	if(decl1 != NULL && decl2 != NULL && decl1->type != NULL && decl2->type != NULL){

		if(decl1->type->typeclass == 3 && decl2->type->typeclass == 0 ) // pointer + int
			after = clonedecl(decl1);
		else if(decl1->type->typeclass == 0 && decl2->type->typeclass == 3 ) // int + pointer
			after = clonedecl(decl2);
		else if(decl1->type->typeclass == 0 && decl2->type->typeclass == 0 ) // int + int
			after = clonedecl(decl1);
	}

	if(after == NULL)	print_error("not computable");

	return after;
}



struct decl *checkfunctioncall(struct decl *procptr, struct decl *actuals)
{
	if(procptr == NULL)
		return NULL;

	struct ste *formals = procptr->formals;
	int diff = 0;

	while(formals != NULL && actuals != NULL) {
		struct decl* comp_type = check_compatible_type(formals->decl->type, actuals, NULL);
		if(comp_type == NULL){
			diff = 1;
			break;
		}
		formals = formals->prev;
		actuals = actuals->next;
	}
	if(formals != NULL || actuals != NULL)	diff = 1;

	if(diff == 1)
		print_error("actual args are not equal to formal args");

	return (procptr->returntype); /* for decl of the call */
}

void check_isarray(struct decl* arraytype){
	if(arraytype != NULL && arraytype->declclass == 3 && arraytype->typeclass == 2) // array
		return;
	if(arraytype != NULL && arraytype->declclass == 3 && arraytype->typeclass == 3) // ptr
		return;
	print_error("variable is not array");
}


struct decl* arrayaccess(struct decl* arrayptr, struct decl* indexptr){

	if(arrayptr != NULL)	check_isarray(arrayptr->type);

//	check_compatible_type(indexptr, inttype, "not int type");

	if(arrayptr != NULL && arrayptr->type != NULL){
		if(arrayptr->type->typeclass == 2) // array
			return clonedecl(arrayptr->type->elementvar);
		if(arrayptr->type->typeclass == 3){ // ptr
			return removepointerdecl(arrayptr);
		}
	}
	return NULL;
}

void check_isstruct(struct decl* structtype, char* error_msg){
	if(structtype != NULL && structtype->declclass == 3 && structtype->typeclass == 4)
		return;
	print_error(error_msg);
}

struct decl* structaccess(struct decl* structptr, struct id* fieldid){

	if(structptr != NULL)	check_isstruct(structptr->type, "variable is not struct");
	
	struct decl* ret = NULL;

	if(structptr != NULL && structptr->type != NULL){
		struct ste* ste = structptr->type->fieldlist;
		while(ste != NULL){
			if(ste->name == fieldid){
				ret = ste->decl;
				break;
			}
			ste = ste->prev;
		}
		if(ret == NULL)
			print_error("struct not have same name field");
	}
	return ret;
}

void declare(struct id* id1, struct decl* decl1){
	// null protection
	if(id1 == NULL || decl1 == NULL)
		return;

	struct ste* ste = top->ste;
	// check existence of variable, struct or function
	while(ste != NULL){
		if(top->prev!=NULL && ste == top->prev->ste)
			break;
		if(ste->name == id1 && !(ste->decl == decl1->type) ){	//struct 선언시 struct이름과 변수 이름이 같은 경우 허용. ex) struct a{int x;} a;
			print_error("redeclaration");
			return;
		}
		ste = ste->prev;
	}

	decl1->isglobal = global==top?1:0;
	insert(id1, decl1);

	if(decl1->declclass == 0 || (decl1->declclass == 1 && decl1->type->typeclass == 2)){ // int or const(array)
		decl1->offset = top->counter;
		top->counter = top->counter + decl1->size;
	}
}

struct decl* declare_function(struct id* id1, struct decl* decl1){
	struct decl *ret = lookup(id1);
	if(ret == NULL){// prototype do not exist.
		declare(id1, decl1);
		ret = decl1;
	}

	return ret;
}


void insert_function_formals(struct decl* procdecl, struct ste* new_formals){

	if(procdecl == NULL || new_formals == NULL)	return;

	struct decl* new_return = new_formals->decl;
	new_formals = new_formals->prev;

	if(procdecl->defined == 0){
		procdecl->returntype = new_return;
		procdecl->formals = new_formals;
		int size = 0;
		while(new_formals != NULL){
			size += new_formals->decl->size;
			new_formals = new_formals->prev;
		}
		procdecl->size = size;
	} else {

		struct ste *formals = procdecl->formals;
		int diff = 0;

		while(formals != NULL && new_formals != NULL) {
			struct decl* comp_type = check_compatible_type(formals->decl->type, new_formals->decl->type, NULL);
			if(comp_type == NULL){
				diff = 1;
				break;
			}
			formals = formals->prev;
			new_formals = new_formals->prev;
		}
		if(formals != NULL || new_formals != NULL)	diff = 1;

		if(diff == 1)
			print_error("prototype formal args are not equal to definition formal args");

		if(procdecl->returntype->typeclass != new_return->typeclass)
			print_error("prototype return type are not equal to definition return type");
	}

}


struct decl* check_assign(struct decl* LHS, struct decl* RHS){
	struct decl* ret = NULL;
	check_isvar(LHS, "LHS is not a variable");
	if(LHS != NULL && RHS != NULL){
		if(RHS->declclass == 2) // func
			check_compatible_type(LHS->type, RHS->returntype, "LHS and RHS are not same type");
		else // general
			check_compatible_type(LHS->type, RHS->type, "LHS and RHS are not same type");
		ret = LHS->type;
	}
	return ret;
}


void   print_error(char* s){
//	printf("%s:%d:error:%s\n", get_file_name(), read_line(), s);
}


int    yyerror (char* s)
{
//	fprintf (stderr, "%s\n", s);
}

