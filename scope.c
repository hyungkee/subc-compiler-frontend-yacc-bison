/***************************************************************
 * File Name    : hash.c
 * Description
 *      This is an implementation file for the open hash table.
 *
 ****************************************************************/

#include "subc.h"



void insert(struct id* id1, struct decl* decl1){
	struct ste* new_ste = (struct ste*)malloc(sizeof(struct ste));
	new_ste->name = id1;
	new_ste->decl = decl1;
	new_ste->prev = top->ste;

	top->ste = new_ste;
}

void push_scope(int counter){
	struct node* new_node = (struct node*)malloc(sizeof(struct node));
	new_node->next = NULL;
	new_node->prev = top;
	new_node->init_counter = counter;
	new_node->counter = counter;
	if(top!=NULL)	top->next = new_node;
	top = new_node;

	if(top->prev!=NULL)	top->ste = top->prev->ste;
}

void set_global_scope(){
	global = top;
}

int get_scope_size(){
	return top->counter - top->init_counter;
}

int get_scope_counter(){
	return top->counter;
}

struct ste* pop_scope(){
	struct ste* ret = top->ste;
	struct ste* ste = top->ste;

// there was no insertion
	if(top->prev!=NULL && ste == top->prev->ste)
		ret = ste = NULL;

// travel list
	while(ste!=NULL && ste->prev!=NULL && ste->prev!=top->prev->ste){
		ste = ste->prev;
	}
// cut listed flow
	if(ste!=NULL)	ste->prev = NULL;

// memmory free
	struct node* prev = top->prev;
	free(top);
	top = prev;

// make reverse list
	{
		ste = ret;
		struct ste* prev;
		if(ste != NULL){
			prev = ste->prev;
			ste->prev = NULL;
		}
		while(ste!=NULL && prev!=NULL){
			struct ste* mprev = prev->prev;
			prev->prev = ste;

			ste = prev;
			prev = mprev;
		}
		ret = ste; // reversed list
	}

	return ret;
}

void remove_scope(struct ste* ste){
// ste is cut list
// memmory free
	while(ste!=NULL){
		struct ste* prev = ste->prev;
		free(ste);
		ste = prev;
	}
}

struct ste* regist_struct(struct ste* ste){
// retravel and add struct
	struct ste* ret = ste;
	while(ste!=NULL){
		struct decl* decl = ste->decl;
		// struct re-insert
		if(decl!=NULL && decl->declclass==3 && decl->typeclass==4)
			insert(ste->name, decl);
		ste = ste->prev;
	}
	return ret; // simple re-return
}

struct decl *lookup(struct id* name){
	struct ste* ste = top->ste;
// top down search in stack
	while(ste!=NULL){
		if(ste->name == name)
			return ste->decl;
		ste = ste->prev;
	}
	return NULL;
}

struct decl *lookup_func(){
	struct ste* ste = top->ste;
// top down search in stack
	while(ste!=NULL){
		if(ste->decl->declclass == 2) // func
			return ste->decl;
		ste = ste->prev;
	}
	return NULL;
}

struct decl *lookup_struct(struct id *name){
	struct ste* ste = top->ste;
// top down search in stack
	while(ste!=NULL){
		if(ste->name == name && ste->decl->declclass == 3 && ste->decl->typeclass == 4) // struct
			return ste->decl;
		ste = ste->prev;
	}
	return NULL;
}

struct id* find_id(struct decl *decl){
	struct ste* ste = top->ste;
// top down search in stack
	while(ste!=NULL){
		if(ste->decl == decl->origin) // struct
			return ste->name;
		ste = ste->prev;
	}
	return NULL;	
}



