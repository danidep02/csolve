(*
 * Copyright © 2009 The Regents of the University of California. All rights reserved. 
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
 * TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONAst.Symbol.
 *
 *)

(* This module implements basic datatypes and operations on constraints *)
type tag  = int
type subs = (Ast.Symbol.t * Ast.expr) list            (* [x := e] *) 
type refa = Conc of Ast.pred | Kvar of subs * Ast.Symbol.t
type reft = Ast.Symbol.t * Ast.Sort.t * (refa list)   (* { VV: t | [ra] } *)
type envt = reft Ast.Symbol.SMap.t

type t 
type wf

type soln = Ast.pred list Ast.Symbol.SMap.t

type deft = Srt of Ast.Sort.t 
          | Axm of Ast.pred 
          | Cst of t 
          | Wfc of wf 
          | Sol of Ast.Symbol.t * Ast.pred list
          | Qul of Ast.Qualifier.t

val kvars_of_reft    : reft -> (subs * Ast.Symbol.t) list
val kvars_of_t       : t -> (subs * Ast.Symbol.t) list
val apply_substs     : subs -> Ast.pred -> Ast.pred
val preds_of_refa    : soln -> refa -> Ast.pred list
val env_of_bindings  : (Ast.Symbol.t * reft) list -> envt
val bindings_of_env  : envt -> (Ast.Symbol.t * reft) list
val is_simple        : t -> bool

val sol_cleanup      : soln -> soln
val sol_read         : soln -> Ast.Symbol.t -> Ast.pred list
val sol_add          : soln -> Ast.Symbol.t -> Ast.pred list -> (bool * soln)
val group_sol_add    : soln -> Ast.Symbol.t list -> (Ast.Symbol.t * Ast.pred) list -> (bool * soln)
val group_sol_update : soln -> Ast.Symbol.t list -> (Ast.Symbol.t * Ast.pred) list -> (bool * soln)

val print_env        : soln option -> Format.formatter -> envt -> unit
val print_wf         : soln option -> Format.formatter -> wf -> unit
val print_t          : soln option -> Format.formatter -> t -> unit
val print_soln       : Format.formatter -> soln -> unit
val to_string        : t -> string 

val print_reft       : soln option -> Format.formatter -> reft -> unit

val make_reft        : Ast.Symbol.t -> Ast.Sort.t -> refa list -> reft
val vv_of_reft       : reft -> Ast.Symbol.t
val sort_of_reft     : reft -> Ast.Sort.t
val ras_of_reft      : reft -> refa list
val shape_of_reft    : reft -> reft
val theta            : subs -> reft -> reft

val make_t           : envt -> Ast.pred -> reft -> reft -> tag option -> t
val env_of_t         : t -> envt
val grd_of_t         : t -> Ast.pred
val lhs_of_t         : t -> reft
val rhs_of_t         : t -> reft
val id_of_t          : t -> tag

val make_wf          : envt -> reft -> tag option -> wf
val env_of_wf        : wf -> envt
val reft_of_wf       : wf -> reft

val validate         : t list -> t list
