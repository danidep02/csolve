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

module CM = CilMisc
module VM = CM.VarMap
module Sy = Ast.Symbol
module Su = Ast.Subst
module FI = FixInterface
module SM = Misc.StringMap
module YM = Ast.Symbol.SMap
module ST = Ssa_transform
module Ix = Ctypes.Index
module Co = Constants
module Q  = Ast.Qualifier
module Ci = Consindex
module E  = Errormsg

open Misc.Ops

type scalar_const = Offset of int | UpperBound of int | Periodic of int * int

(***************************************************************************)
(******************** Meta Qualifiers for Scalar Invariants ****************)
(***************************************************************************)

let value_var       = Ast.Symbol.value_variable Ast.Sort.t_int
let const_var       = Ast.Symbol.mk_wild ()
let param_var       = Ast.Symbol.mk_wild ()

(* v = c *)
let p_v_eq_c        = Ast.pEqual (Ast.eVar value_var, Ast.eVar const_var)
(* v < c *)
let p_v_lt_c        = Ast.pAtom (Ast.eVar value_var, Ast.Lt, Ast.eVar const_var)
(* v = _ + c *)
let p_v_eq_x_plus_c = Ast.pEqual (Ast.eVar value_var, Ast.eBin (Ast.eVar param_var, Ast.Plus, Ast.eVar const_var))
(* v < _ + c *)
let p_v_lt_x_plus_c = Ast.pAtom (Ast.eVar value_var, Ast.Lt, Ast.eBin (Ast.eVar param_var, Ast.Plus, Ast.eVar const_var))

let quals_of_pred p = List.map (fun t -> Q.create value_var t p) [Ast.Sort.t_int]


(***************************************************************************)
(************************* Scrape Scalar Qualifiers ************************)
(***************************************************************************)

let hash_of_ciltype t = 
  Pretty.dprintf "%a ### %a " Cil.d_typsig (Cil.typeSig t) Cil.d_attrlist (Cil.typeAttrs t)
  |> Pretty.sprint ~width:80

let type_decs_of_file (cil: Cil.file) : (Cil.location * Cil.typ) list =
  let x = ref [] in 
  CM.iterVars cil begin fun v -> match v.Cil.vtype with 
    | Cil.TFun (t,_,_,_) | t -> x := (v.Cil.vdecl, t) :: !x
  end; 
  !x 
  |> Misc.kgroupby (snd <+> hash_of_ciltype)
  |> Misc.map (function (_,x::_) -> x)

let scalar_consts_of_polarity n m = function
  | Ctypes.PosB k -> [UpperBound (n + m*k)]
  | _             -> []

let scalar_consts_of_index = function
  | Ctypes.Index.IBot            -> []
  | Ctypes.Index.IInt n          -> [Offset n] 
  | Ctypes.Index.ISeq (n, m, po) -> [Offset n;  Periodic (n, m)] ++ (scalar_consts_of_polarity n m po)
  
let preds_of_scalar_const = function
  | Offset c ->
      [p_v_eq_c; p_v_eq_x_plus_c] 
      |>: (Misc.flip Ast.substs_pred) (Ast.Subst.of_list [const_var, Ast.eInt c])
      
  | UpperBound c ->
      [p_v_lt_c; p_v_lt_x_plus_c] 
      |>: (Misc.flip Ast.substs_pred) (Ast.Subst.of_list [const_var, Ast.eInt c])
  
  | Periodic (c, d) -> (* TODO: MODZ_c_d(v), MODZ_c_d(v - _) *)
      []

(* AXIOMS for MODZ
(1) <bas> MODZ_c_d(c)
(2) <ind> forall x,y,c,d: MODZ_c_d(x) and y = x + d => MODZ_c_d(y)
(3) <ind> forall x,y,c,d: MODZ_c_d(x) and y = x - d => MODZ_c_d(y)
*)

let dump_quals_to_file (fname: string) (qs: Q.t list) : unit = 
  let oc  = open_out fname in
  let ppf = Format.formatter_of_out_channel oc in
  Format.fprintf ppf "@[%a@]\n" (Misc.pprint_many true "\n" Q.print) qs;
  close_out oc

let scalar_quals_of_file cil = 
  cil 
  |> type_decs_of_file
  |> Misc.map (Misc.uncurry Genspec.spec_of_type)
  |> Misc.flap (fun (ct, st) -> Ctypes.I.CType.refinements_of_t ct ++ Ctypes.I.Store.indices_of_t st)
  |> Misc.flap scalar_consts_of_index
  |> Misc.sort_and_compact
  |> Misc.flap preds_of_scalar_const
  |> Misc.flap quals_of_pred
  |> (++) (FI.quals_of_file (Co.get_lib_squals ()))
  >> dump_quals_to_file (!Co.liquidc_file_prefix ^ ".squals")

(***************************************************************************)
(********************** Convert Predicates To Indices **********************)
(***************************************************************************)

let const_of_subst su =
  su |> Ast.Subst.to_list
     >> (fun xs ->  let b = List.exists ((=) const_var) (List.map fst xs) in
                    if not b then Format.printf "Const of subst %a \n" Su.print su)
     |> Misc.do_catch (Format.sprintf "Scalar.const_of_subst") (List.assoc const_var)
     |> (function Ast.Con (Ast.Constant.Int i), _  -> i | _ -> assertf "Scalar.const_of_subst")

let indexo_of_preds_iint v ps =
  let p_v_eq_c = [value_var, Ast.eVar v] |> Ast.Subst.of_list |> Ast.substs_pred p_v_eq_c in
  ps |> Misc.map_partial (Ast.unify_pred p_v_eq_c)
     |> List.map const_of_subst
     |> (function [] -> None | c::cs -> Some (Ix.IInt (List.fold_left min c cs)))

let indexo_of_preds_iint v ps = 
  try indexo_of_preds_iint v ps with ex ->
    (Printf.printf "indexo_of_preds_iint v = %s, ps =%s" 
    (Sy.to_string v)
    (Ast.Predicate.to_string (Ast.pAnd ps));
    raise ex)


let indexo_of_preds_iseqb v ps = 
  None (* TODO *)

let indexo_of_preds_iseq  v ps = 
  None (* TODO *) 

let index_of_pred v = 
  let v = FI.name_of_varinfo v in
  function
  | Ast.And ps, _ ->
    [ indexo_of_preds_iint v
    ; indexo_of_preds_iseqb v
    ; indexo_of_preds_iseq v ]
    |> Misc.maybe_chain ps Ix.top
  | _ -> assertf "Scalar.index_of_pred"

(***************************************************************************)
(************************ Generate Scalar Constraints **********************)
(***************************************************************************)

let generate spec tgr gnv scim : Ci.t =
  ([], [], [], [])
  |> Ci.create  
  |> ConsVisitor.cons_of_scis tgr gnv FI.refstore_empty scim None

(***************************************************************************)
(*************************** Solve Scalar Constraints **********************)
(***************************************************************************)

let solve cil ci = 
  scalar_quals_of_file cil 
  |> Ci.force ci (!Co.liquidc_file_prefix^".scalar")
  >> (fun _ -> Errormsg.log "DONE: GOOBER GOOBER \n")
  |> SM.map (VM.mapi index_of_pred)

(***************************************************************************)
(*********************************** API ***********************************)
(***************************************************************************)

let scalarinv_of_scim cil spec tgr gnv ci =
  ci 
  >> FI.annot_clear 
  |> generate spec tgr gnv 
  |> solve cil
  >> FI.annot_clear

(***************************************************************************)
(************************* TESTING SCALAR INVS *****************************)
(***************************************************************************)

type scalar_error = 
  | MissingFun of string 
  | MissingVar of string * Cil.varinfo 
  | DiffIndex of string * Cil.varinfo * Ix.t * Ix.t

let d_scalar_error () = function
  | MissingFun fn -> 
      Pretty.dprintf "[SCALAR ERROR in %s] Missing Function" fn
  | MissingVar (fn, v) -> 
      Pretty.dprintf "[SCALAR ERROR in %s] Missing Variable %s" fn v.Cil.vname 
  | DiffIndex (fn, v, ix, ix') ->
      Pretty.dprintf "[SCALAR ERROR in %s] Different Index %s: inferctypes=%a vs scalar=%a" fn 
      v.Cil.vname Ix.d_index ix Ix.d_index ix' 

let check_scalar shm sim = 
  SM.fold begin fun fn { Shape.vtyps = vcts } errs ->
    if not (SM.mem fn sim) then (MissingFun fn) :: errs else 
      let im = SM.find fn sim in
      List.fold_left begin fun errs (v, ct) ->
        if not (VM.mem v im) then MissingVar (fn, v) :: errs else
          let [ix] = Ctypes.I.CType.refinements_of_t ct in
          let ix'  = VM.find v im in
          if ix != ix' then DiffIndex (fn, v, ix, ix') :: errs else []
      end errs vcts 
  end shm []

(* API *) 
let test cil spec tgr gnv scim shm = 
  let sim = scalarinv_of_scim cil spec tgr gnv scim in
  check_scalar shm sim
  >> (List.iter (fun e -> E.warn "%a \n" d_scalar_error e |> ignore))
  |> (function [] -> exit 0 | _ -> exit 1)
