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

(* This file is part of the liquidC Project.*)

(************** Interface between LiquidC and Fixpoint *************)

module IM = Misc.IntMap
module F  = Format
module ST = Ssa_transform
module  C = FixConstraint

module  A = Ast
module  P = A.Predicate
module  E = A.Expression
module Sy = A.Symbol
module Su = A.Subst
module So = A.Sort
module  Q = A.Qualifier

module Ct = Ctypes
module It = Ct.I
module YM = Sy.SMap
module SM = Misc.StringMap
module Co = Constants
module LM = Sloc.SlocMap
module CM = CilMisc
module VM = CM.VarMap
module Ix = Ct.Index
module RCt = Ctypes.RefCTypes

open Misc.Ops
open Cil

let mydebug = false

(*******************************************************************)
(******************************** Names ****************************)
(*******************************************************************)

type name = Sy.t

let string_of_name  = Sy.to_string 
let name_of_varinfo = fun v -> Sy.of_string v.vname
let name_of_string  = fun s -> Sy.of_string s
let varinfo_of_name = fun n -> failwith "TBD: varinfo_of_name"

let name_fresh : unit -> name =
  let t, _ = Misc.mk_int_factory () in
  (fun _ -> t () |> string_of_int |> (^) "lqn#" |> name_of_string)

let base_of_name n = 
  match ST.deconstruct_ssa_name (string_of_name n) with
  | None        -> None 
  | Some (b, _) -> Some (name_of_string b)

(*******************************************************************)
(******************(Basic) Builtin Types and Sorts *****************)
(*******************************************************************)

(* API *)
let string_of_sloc, sloc_of_string = 
  let t = Hashtbl.create 37 in
  begin fun l -> 
    l |> Sloc.to_string 
      >> (fun s -> if not (Hashtbl.mem t s) then Hashtbl.add t s l)
  end,
  begin fun s -> 
    try Hashtbl.find t s with Not_found -> 
      assertf "ERROR: unknown sloc-string"
  end

let so_ref = fun l -> So.t_ptr (So.Loc (string_of_sloc l))
let so_int = So.t_int
let so_skl = So.t_func 0 [so_int; so_int]
let so_bls = So.t_func 1 [So.t_generic 0; So.t_generic 0] 
let so_pun = So.t_func 1 [So.t_generic 0; so_int]
let so_drf = So.t_func 1 [So.t_generic 0; So.t_generic 1]

let vv_int = Sy.value_variable so_int 
let vv_bls = Sy.value_variable so_bls
let vv_skl = Sy.value_variable so_skl
let vv_pun = Sy.value_variable so_pun
let vv_drf = Sy.value_variable so_drf

let uf_bbegin  = name_of_string "BLOCK_BEGIN"
let uf_bend    = name_of_string "BLOCK_END"
let uf_skolem  = name_of_string "SKOLEM" 
let uf_uncheck = name_of_string "UNCHECKED"
let uf_deref   = name_of_string "DEREF"

(* API *)
let eApp_bbegin  = fun x -> A.eApp (uf_bbegin,  [x])
let eApp_bend    = fun x -> A.eApp (uf_bend,    [x])
let eApp_uncheck = fun x -> A.eApp (uf_uncheck, [x])
let eApp_deref   = fun x so -> A.eCst (A.eApp (uf_deref, [x]), so)
let eApp_skolem  = fun x -> A.eApp (uf_skolem, [x])

(* API *)
let axioms      = [A.pEqual (A.zero, eApp_bbegin A.zero)]
let sorts       = [] 
let builtinm    = [(uf_bbegin,  C.make_reft vv_bls so_bls [])
                  ;(uf_bend,    C.make_reft vv_bls so_bls [])
                  ;(uf_skolem,  C.make_reft vv_skl so_skl [])
                  ;(uf_uncheck, C.make_reft vv_pun so_pun [])
                  ;(uf_deref,   C.make_reft vv_drf so_drf [])]
                  |> YM.of_list
(* API *)
let quals_of_file fname =
  try
    let _ = Errorline.startFile fname in
      fname
      |> open_in 
      |> Lexing.from_channel
      |> FixParse.defs FixLex.token
      |> Misc.map_partial (function C.Qul p -> Some p | _ -> None)
  with Sys_error s ->
    Errormsg.warn "Error reading qualifiers: %s@!@!Continuing without qualifiers...@!@!" s; []

(* API *)
let maybe_deref e =
  match A.Expression.unwrap e with
  | A.App (f, [e']) when f = uf_deref -> Some e'
  | A.App (f, _   ) when f = uf_deref -> assertf "maybe_deref"
  | _                                 -> None 

(* API *)

