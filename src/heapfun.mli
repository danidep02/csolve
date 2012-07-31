
(*
 * Copyright © 1990-2009 The Regents of the University of California. All rights reserved. 
 *
 * Permission is hereby granted, without written agreement and without 
 * license or royalty fees, to use, copy, modify, and distribute this 
 * software and its documentation for any purpose, provided that the 
 * above copyright notice and the following two paragraphs appear in 
 * all copies of this software. 
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY 
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES 
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN 
 * IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY 
 * OF SUCH DAMAGE. 
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS 
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION 
 * TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *)

type intrs = Sloc.t list

type 'a def

type ref_def = FixConstraint.reft def
type var_def = Ctypes.VarRefinement.t def
type ind_def = Ctypes.I.T.refinement def

type env  = var_def FixMisc.StringMap.t

val flocs_of : 'a def -> Sloc.t list
val frefs_of : 'a def -> 'a list
val unfs_of  : 'a def -> intrs list
val rhs_of   : 'a def -> 'a Ctypes.prestore

val def_of_intlist : var_def
val test_env : env

val fresh_unfs_of_hf : Sloc.t -> string -> env -> intrs list

val gen : 'a Ctypes.hf_appl -> intrs list -> 
          Sloc.SlocSlocSet.t -> Ctypes.store ->
          env -> Sloc.SlocSlocSet.t * Ctypes.store

val ins : Sloc.t -> Sloc.t list -> intrs list -> 
          Sloc.SlocSlocSet.t -> Ctypes.store -> env ->
          Sloc.SlocSlocSet.t * Ctypes.store

val shape_in_env : string -> Sloc.t list -> env ->
                   Ctypes.store
                   
val expand_cspec_stores  : Ctypes.cspec -> env ->
                           Ctypes.cspec * Ctypes.ind_hf_appl list

val contract_store       : Ctypes.store -> Ctypes.ind_hf_appl list
                                        -> env -> Ctypes.store    
