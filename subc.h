/******************************************************
 * File Name   : subc.h
 * Description
 *    This is a header file for the subc program.
 ******************************************************/

#ifndef __SUBC_H__
#define __SUBC_H__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* structure for ID */
struct id {
      char *name;
      int lextype;
};

/* structure for stack */
struct node {
    struct ste	*ste;
    struct node *prev;
    struct node *next;
    int          init_counter;
    int          counter;
};

struct laVal {
    int start_label;
    int escape_label;
};

/* structure for ste */
struct ste {
    struct id	*name;
    struct decl	*decl;
    struct ste	*prev;
};


/* structure for decl */
struct decl {
    int		declclass;	/* DECL Class: VAR, CONST, FUNC, TYPE		*/
    struct decl	*type;		/* VAR, CONST: pointer to its type decl		*/
    int		value;		/* CONST: value of integer const		*/
    char	*char_value;	/* CONST: value of char const			*/
    struct ste	*formals;	/* FUNC: ptr to formals list			*/
    struct decl	*returntype;	/* FUNC: ptr to return TYPE decl		*/
    int         defined;        /* FUNC: check of function definition           */
    int		typeclass;	/* TYPE: type class: int, array, ptr		*/
    struct decl	*elementvar;	/* TYPE (array): ptr to element VAR decl	*/
    int		num_index;	/* TYPE (array): number of elements		*/
    struct ste	*fieldlist;	/* TYPE (struct): ptr to field list		*/
    struct decl	*ptrto;		/* TYPE (pointer): type of the pointer		*/
    int         ptrcoef;	/* ALL: for check temp decls                    */
    int         offset;		/* ALL: local offset                            */
    int         isglobal;	/* ALL: isglobal                                */
    int		size;		/* ALL: size in bytes				*/
    struct decl *origin;        /* ALL: origin for clone decl                   */
    struct ste	**scope;	/* VAR: scope when VAR declared			*/
    struct decl	*next;		/* For list_of_variables declarations		*/
};				/* Or parameter check of function call		*/

/* For hash table */
unsigned hash(char *name);
struct id *enter(int lextype, char *name, int length);
struct id *hash_lookup(char *name);

/* For scope table */
void push_scope(int counter);
void set_global_scope();
struct ste* pop_scope();
int get_scope_counter();
int get_scope_size();
struct ste* regist_struct(struct ste* ste);
void remove_scope(struct ste* ste);
void insert(struct id* id1, struct decl* decl1);
struct decl *lookup(struct id *name);
struct decl *lookup_func();
struct decl *lookup_struct(struct id *name);
struct id* find_id(struct decl *decl);

/* For sementic analysis */
struct decl* makeprocdecl();
struct decl* maketypedecl(int type);
struct decl* makestructdecl(struct ste* ste);
struct decl* makeconstdecl(struct decl* decl1);
struct decl* makeconstdecl_int(int int_value);
struct decl* makeconstdecl_char(char* car_value);
struct decl* makevardecl(struct decl* decl1);
struct decl* makepointerdecl(int cnt, struct decl* decl1);
struct decl* makearraydecl(struct decl* decl1, struct decl* decl2);
struct decl* findcurrentdecl(struct id* type);
struct decl* findstructdecl(struct id* type);

struct decl* arrayaccess(struct decl* arrayptr, struct decl* indexptr);
struct decl* structaccess(struct decl* structptr, struct id* fieldid);

void declare(struct id* id1, struct decl* decl1);
struct decl* declare_function(struct id* id1, struct decl* decl1);

void check_struct_new(struct id* id);
void check_isarray(struct decl* arraytype);
void check_isstruct(struct decl* structtype, char* error_msg);
void check_isvar(struct decl* var, char* error_msg);
void check_isproc(struct decl* proc, char* error_msg);

void check_can_inc(struct decl* var);

void check_struct_incomplete(struct decl* structdecl);

void insert_function_formals(struct decl* procdecl, struct ste* new_formals);


struct decl* check_assign(struct decl* LHS, struct decl* RHS);

struct decl *check_compatible_type(struct decl* type1, struct decl* type2, char* error_message);
struct decl *check_compatible_type_OP(struct decl* type1, struct decl* type2, char* error_message);
struct decl *plusdecl(struct decl* decl1, struct decl* decl2);
struct decl *checkfunctioncall(struct decl *procptr, struct decl *actuals);
struct decl* clonedecl(struct decl* decl);
struct decl* addtypedecl(struct decl* decl1, struct decl* decl2);

struct decl* typevalue(struct decl* decl);
void pushstelist(struct ste* ste);

struct decl* makepointerdecl(int cnt, struct decl* decl1);
struct decl* addpointerdecl(struct decl* decl1);
struct decl* removepointerdecl(struct decl* decl1);

/* Stack */
struct node* top;
struct node* bot;
struct node* global;

/* types */
struct decl* inttype;
struct decl* chartype;
struct decl* voidtype;
struct id* returnid;

int read_line();
char* get_file_name();

/* for code generation */

void load_var(struct decl* decl);
void load_fetch(struct decl* decl, int os);
void load_assign(struct decl* type, struct decl* decl);

int check_same_trans_var(struct decl* decl1, struct decl* decl2);

void BinaryOperation(char* str);

/* for break, continue */
int start_label;
int escape_label;

FILE* fout;
FILE* fout_temp;
FILE* fout_file;

int strcounter;
int labelcounter;

#endif

