/* ex: set ro ft=c:
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *
 * This file is generated automatically by tools/dev/nci_thunk_gen.pir
 *
 * Any changes made here will be lost!
 *
 */

/* src/nci/core_thunks.c
 *  Copyright (C) 2010, Parrot Foundation.
 *  Overview:
 *     Native Call Interface routines. The code needed to build a
 *     parrot to C call frame is in here
 *  Data Structure and Algorithms:
 *  History:
 *  Notes:
 *  References:
 */


#include "parrot/parrot.h"
#include "parrot/nci.h"
#include "pmc/pmc_nci.h"


#ifdef PARROT_IN_EXTENSION
/* external libraries can't have strings statically compiled into parrot */
#  define CONST_STRING(i, s) Parrot_str_new_constant((i), (s))
#else
#  include "core_thunks.str"
#endif

/* HEADERIZER HFILE: none */
/* HEADERIZER STOP */

/* All our static functions that call in various ways. Yes, terribly
   hackish, but that is just fine */



 void
Parrot_nci_load_core_thunks(PARROT_INTERP)
 {
    PMC * const iglobals = interp->iglobals;
    PMC *nci_funcs;
    PMC *temp_pmc;

    PARROT_ASSERT(!(PMC_IS_NULL(iglobals)));

    nci_funcs = VTABLE_get_pmc_keyed_int(interp, iglobals, IGLOBALS_NCI_FUNCS);
    PARROT_ASSERT(!(PMC_IS_NULL(nci_funcs)));


}


/*
 * Local variables:
 *   c-file-style: "parrot"
 * End:
 * vim: expandtab shiftwidth=4 cinoptions='\:2=2' :
 */

