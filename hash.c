/***************************************************************
 * File Name    : hash.c
 * Description
 *      This is an implementation file for the open hash table.
 *
 ****************************************************************/

#include "subc.h"

#define  HASH_TABLE_SIZE   101

struct nlist {
   struct nlist *next;
   struct id *data;
};

static struct nlist *hashTable[HASH_TABLE_SIZE];

unsigned hash(char *name) {
   /* implementation is given here */
	unsigned index = 5381;
	int c;
	while(c = *name++)
		index = ((index << 5) + index) + c; // index*33 + c

	return index % HASH_TABLE_SIZE;
}

struct id *enter(int lextype, char *name, int length) {
   /* implementation is given here */
	unsigned index = hash(name);
	struct nlist* list = hashTable[index];

	// already exists in hashTable
	for(;list;list = list->next){
		if(strcmp(list->data->name, name) == 0)
			return list->data;
	}

	// make new node
	struct id* newid = (struct id*)malloc(sizeof(struct id));
	newid->lextype = lextype;
	newid->name = (char*)malloc(sizeof(char)*(length+1));
	strcpy(newid->name, name);

	struct nlist* newlist = (struct nlist*)malloc(sizeof(struct nlist));
	newlist->data = newid;
	newlist->next = NULL;

	// insert to hashTable
	if(hashTable[index] == NULL){
		hashTable[index] = newlist;
	}else{
		list = hashTable[index];
		for(;list->next;list = list->next);
		// after this line, list is last object's pointer
		list->next = newlist;
	}
	return newlist->data;
}

struct id *hash_lookup(char *name) {
	unsigned index = hash(name);
	struct nlist* list = hashTable[index];
	for(;list;list = list->next){
		if(strcmp(list->data->name, name) == 0)
			return list->data;
	}
	return NULL;
}
