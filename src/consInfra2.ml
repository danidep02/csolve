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

(*******************************************************************)
(************* Constraint Generation Infrastructure ****************)
(*******************************************************************)

module Cs  = Constants
module ST  = Ssa_transform
module IM  = Misc.IntMap
module SM  = Misc.StringMap
module C   = FixConstraint
module FI  = FixInterface 
module CI  = CilInterface
module EM  = Ctypes.I.ExpMap
module LI  = Inferctypes
module LM  = Sloc.SlocMap
module IIM = Misc.IntIntMap
module CM  = CilMisc

open Misc.Ops
open Cil

type wld = FI.cilenv * FI.refstore * CilTag.t option 

type t_sh = {
  cf      : FI.alocmap;
  astore  : FI.refstore;
  cstoa   : (FI.refstore * Sloc.t list * Refanno.cncm) array; 
  shp     : LI.shape;
}

type t    = {
  tgr     : CilTag.o;
  sci     : ST.ssaCfgInfo;
  ws      : C.wf list;
  cs      : C.t list;
  ds      : C.dep list;
  wldm    : wld IM.t;
  gnv     : FI.cilenv; 
  formalm : unit SM.t;
  undefm  : unit SM.t;
  edgem   : (Cil.varinfo * Cil.varinfo) list IIM.t;
  phibt   : (string, (FI.name * FI.refctype)) Hashtbl.t;
  shapeo  : t_sh option
}

let ctype_of_local locals v =
  try List.assoc v locals with 
    Not_found -> assertf "ctype_of_local: unknown var %s" v.Cil.vname

let strengthen_cloc = function
  | ct, None 
  | (Ctypes.Int (_, _) as ct), _  
  | (Ctypes.Top (_) as ct), _    ->  ct
  | (Ctypes.Ref (_, x)), Some cl -> Ctypes.Ref (cl, x)

let strengthen_refs theta v (vn, cr) =
  let ct  = FI.ctype_of_refctype cr in
  let clo = Refanno.cloc_of_varinfo theta v in
  let ct' = strengthen_cloc (ct, clo) in
  let cr' = FI.t_ctype_refctype ct' cr in 
  (vn, cr')

let is_origcilvar v = 
  match ST.deconstruct_ssa_name v.vname with
  | None -> true
  | _    -> false

let ctype_scalar = Ctypes.void_ctype

let env_of_fdec gnv fdec sho = 
  let strf, typf = match sho with
    | None     -> (id, fun _ -> Ctypes.scalar_ctype)
    | Some shp -> (Misc.map2 (strengthen_refs shp.LI.theta) fdec.sformals, ctype_of_local shp.LI.vtyps) in
  let env0 = 
    FI.ce_find_fn fdec.svar.vname gnv 
    |> FI.args_of_refcfun 
    |> strf 
    |> List.map (Misc.app_fst FI.name_of_string)
    |> FI.ce_adds gnv in
  fdec.slocals 
  |> List.filter is_origcilvar 
  |> Misc.map (FI.name_of_varinfo <*> (FI.t_true <.> typf))
  |> FI.ce_adds env0 

let formalm_of_fdec fdec = 
  List.fold_left (fun sm v -> SM.add v.vname () sm) SM.empty fdec.Cil.sformals

let is_undef_var formalm v = 
  is_origcilvar v && not (SM.mem v.vname formalm)

let make_undefm formalm phia =
  Array.to_list phia
  |> Misc.flatten
  |> List.filter (fun (_,vjs) -> vjs |> List.map snd |> List.exists (is_undef_var formalm))
  |> List.map fst
  |> List.fold_left (fun um v -> SM.add v.vname () um) SM.empty

let eq_tagcloc (cl,t) (cl',t') = 
   Sloc.eq cl cl' && Refanno.tag_eq t t'

let diff_binding conc (al, x) = 
  if LM.mem al conc then
    LM.find al conc |> eq_tagcloc x |> not
  else true

(*
let canon_of_annot = function 
  | Refanno.WGen (cl, al) 
  | Refanno.Gen  (cl, al) 
  | Refanno.Ins  (al, cl) 
  | Refanno.NewC (_, al, cl) -> Some (cl, al)
  | _                        -> None

let alocmap_of_anna a = 
  a |> Array.to_list 
    |> Misc.flatten
    |> Misc.flatten
    |> Misc.map_partial canon_of_annot
    >> List.iter (fun (cl, al) -> ignore <| Pretty.printf "canon: %a -> %a \n" Sloc.d_sloc cl Sloc.d_sloc al)
    |> List.fold_left (fun cf (cl, al) -> AM.add cl al cf) AM.id

*)

let cstoa_of_annots fname gdoms conca astore =
  let emp = FI.refstore_empty in
  Array.mapi begin fun i (conc,conc') ->
    let idom, _ = gdoms.(i) in 
    if idom < 0 then (emp, [], conc') else
      let _,idom_conc = conca.(idom) in
      let joins, ins  = Sloc.slm_bindings conc 
                        |> List.partition (diff_binding idom_conc) in
      let inclocs     = List.map (snd <+> fst) ins in
      let sto         = joins 
                        |> List.fold_left begin fun sto (al, (cl, _)) -> 
                             FI.refstore_get astore al |> FI.refstore_set sto cl
                           end emp
                        |> FI.store_of_refstore 
                        |> FI.refstore_fresh fname in
      (sto, inclocs, conc')
  end conca

let edge_asgnm_of_phia phia =
  Misc.array_to_index_list phia
  |> List.fold_left begin fun em (j, asgns) -> 
       Misc.transpose asgns 
       |> List.fold_left begin fun em (i, vvis) -> 
            IIM.add (i,j) (vvis : (Cil.varinfo * Cil.varinfo) list) em 
          end em  
     end IIM.empty 

let create_shapeo tgr gnv env gst sci = function
  | None -> 
      ([], [], [], None)
  | Some shp ->
      let istore  = FI.ce_find_fn sci.ST.fdec.svar.vname gnv 
                    |> FI.stores_of_refcfun |> fst |> FI.RefCTypes.Store.upd gst in
      let lastore = FI.refstore_fresh sci.ST.fdec.svar.vname shp.LI.store in
      let astore  = FI.RefCTypes.Store.upd gst lastore in
      let cstoa   = cstoa_of_annots sci.ST.fdec.svar.vname sci.ST.gdoms shp.LI.conca astore in
      let cf      = Refanno.aloc_of_cloc shp.LI.theta in
      let tag     = CilTag.make_t tgr sci.ST.fdec.svar.vdecl sci.ST.fdec.svar.vname 0 0 in
      let loc     = sci.ST.fdec.svar.vdecl in
      let ws      = FI.make_wfs_refstore cf env lastore tag in
      let cs, ds  = FI.make_cs_refstore cf env Ast.pTrue istore astore false None tag loc in 
      ws, cs, ds, Some { cf = cf; astore  = astore; cstoa = cstoa; shp = shp }

let create tgr gnv gst sci sho = 
  let formalm = formalm_of_fdec sci.ST.fdec in
  let env     = env_of_fdec gnv sci.ST.fdec sho in
  let ws, cs, ds, sh_me = create_shapeo tgr gnv env gst sci sho in
  {tgr     = tgr;
   sci     = sci;
   ws      = ws;
   cs      = cs;
   ds      = ds;
   wldm    = IM.empty;
   gnv     = env;
   formalm = formalm;
   undefm  = make_undefm formalm sci.ST.phis;
   edgem   = edge_asgnm_of_phia sci.ST.phis;
   phibt   = Hashtbl.create 17;
   shapeo  = sh_me}

let add_cons (ws, cs, ds) me =
  {me with cs = cs ++ me.cs; ws = ws ++ me.ws; ds = ds ++ me.ds}

let add_wld i wld me = 
  {me with wldm = IM.add i wld me.wldm}

let get_cons me =
  (me.ws, me.cs, me.ds)

let get_astore = function { shapeo = Some x } -> x.astore | _ -> FI.refstore_empty 

let stmt_of_block me i =
  me.sci.ST.cfg.Ssa.blocks.(i).Ssa.bstmt

let get_fname me = 
  me.sci.ST.fdec.svar.vname 

let length_of_stmt stmt = match stmt.skind with 
  | Instr is -> List.length is
  | Return _ -> 0 
  | _        -> (if !Cs.safe then Errormsg.error "unknown stmt: %a" d_stmt stmt); 0 

let annotstmt_of_block me i = 
  match me.shapeo with 
  | Some {shp = shp} ->  
      (shp.LI.anna.(i), shp.LI.bdcks.(i), stmt_of_block me i)
(*  | None     -> 
      let stmt = stmt_of_block me i in
      ((stmt |> length_of_stmt |> Misc.clone []), [], stmt)
*)

let get_alocmap = function {shapeo = Some shp} -> shp.cf 
                      (* | _ -> (fun _ -> None) *)

let location_of_block me i =
  Cil.get_stmtLoc (stmt_of_block me i).skind 

let tag_of_instr me block_id instr_id loc = 
  CilTag.make_t me.tgr loc (get_fname me) block_id instr_id

let rec doms_of_block gdoms acc i =
  if i <= 0 then acc else
    let (idom,_) as x = gdoms.(i) in 
    doms_of_block gdoms (x::acc) idom 

let pred_of_block ifs (i,b) =
  match ifs.(i) with 
  | None         -> 
      assertf "pred_of_block"
  | Some (e,_,_) -> 
      let p = CI.pred_of_cilexp e in
      if b then p else (Ast.pNot p)

let entry_guard_of_block me i = 
  i |> doms_of_block me.sci.ST.gdoms []
    |> Misc.map_partial (function (i,Some b) -> Some (i,b) | _ -> None)
    |> Misc.map (pred_of_block me.sci.ST.ifs)
    |> Ast.pAnd

let guard_of_block me i jo = 
  let p = entry_guard_of_block me i in
  match jo with None -> p | Some j -> 
    if not (Hashtbl.mem me.sci.ST.edoms (i, j)) then p else
      let b' = Hashtbl.find me.sci.ST.edoms (i, j) in 
      let p' = pred_of_block me.sci.ST.ifs (i, b') in
      Ast.pAnd [p; p']

let succs_of_block = fun me i -> me.sci.ST.cfg.Ssa.successors.(i)
let csto_of_block  = fun {shapeo = Some shp} i -> shp.cstoa.(i) |> fst3 
let asgns_of_edge  = fun me i j -> try IIM.find (i, j) me.edgem with Not_found -> []

let annots_of_edge me i j =
  match me with 
  | {shapeo = Some shp} ->
      let iconc' = shp.cstoa.(i) |> thd3 in
      let jsto   = shp.cstoa.(j) |> fst3 in
      LM.fold begin fun al (cl, t) acc -> 
        if FI.refstore_mem cl jsto then acc else 
          if Refanno.tag_dirty t then (Refanno.Gen (cl, al) :: acc) else
            (Refanno.WGen (cl, al) :: acc)
      end iconc' []  
  (* | _ -> [] *)

(*
let is_formal fdec v =
  fdec.sformals
  |> Misc.map (fun v -> v.vname)
  |> List.mem v.vname 
*)

let is_undefined me v = 
  is_undef_var me.formalm v || SM.mem v.vname me.undefm

let ctype_of_expr me e = 
  match me.shapeo with 
  | Some {shp = shp} -> begin 
      try EM.find e shp.LI.etypm with Not_found -> 
        let _ = Errormsg.error "ctype_of_expr: unknown expr = %a" Cil.d_exp e in
        assertf "Not_found in ctype_of_expr"
    end
  | _ -> assertf "ctype_of_expr" (* Ctypes.scalar_ctype *) 

let ctype_of_varinfo ctl v =
  try List.assoc v ctl with Not_found ->
    assertf "ctype_of_varinfo: unknown var %s" v.Cil.vname

let ctype_of_varinfo me v =
  match me.shapeo with 
  | Some {shp = shp} ->
      let ct  = ctype_of_varinfo shp.LI.vtyps v in
      let clo = Refanno.cloc_of_varinfo shp.LI.theta v in
      strengthen_cloc (ct, clo)
      (* >> Pretty.printf "ctype_of_varinfo v = %s, ct = %a \n" v.vname Ctypes.d_ctype ct *)
  | _ -> ctype_scalar
 
let refctype_of_global me v =
  FI.ce_find (FI.name_of_string v.Cil.vname) me.gnv

let phis_of_block me i = 
  me.sci.ST.phis.(i) 
  |> Misc.map fst
  >> List.iter (fun v -> ignore <| Pretty.printf "phis_of_block %d: %s \n" i v.Cil.vname)

let outwld_of_block me i =
  IM.find i me.wldm

let bind_of_phi me v =
  Misc.do_memo me.phibt begin fun v -> 
    let vn = FI.name_of_varinfo v in
    let cr = ctype_of_varinfo me v |> FI.t_fresh in
    (vn, cr)
  end v v.vname

let idom_of_block = fun me i -> fst me.sci.ST.gdoms.(i)

let inenv_of_block me i =
  if idom_of_block me i < 0 then
    me.gnv
  else
    let env0  = idom_of_block me i |> outwld_of_block me |> fst3 in
    let phibs = phis_of_block me i |> List.map (bind_of_phi me) in
    FI.ce_adds env0 phibs

let extend_wld_with_clocs me j loc tag wld = 
  match me with
  | {shapeo = Some shp} ->
      let _, sto, _    = idom_of_block me j |> outwld_of_block me in 
      let csto,incls,_ = shp.cstoa.(j) in
      wld
      (* Copy "inherited" conc-locations *)
      |> Misc.flip (List.fold_left begin fun (env, st, t) cl ->
          (env, (FI.refstore_get sto cl |> FI.refstore_set st cl), t)
         end) incls
      (* Add fresh bindings for "joined" conc-locations *)
      |> FI.refstore_fold begin fun cl ld wld ->
          fst <| FI.extend_world shp.cf csto cl cl false loc tag wld
         end csto 
  | _ -> assertf "extend_wld_with_clocs: shapeo = None"
 
let inwld_of_block me = function
  | j when idom_of_block me j < 0 ->
      (me.gnv, get_astore me, None)
  | j ->
      let loc          = location_of_block me j in
      let tag          = tag_of_instr me j 0 loc in
      (inenv_of_block me j, get_astore me, Some tag)
      |> ((me.shapeo <> None) <?> extend_wld_with_clocs me j loc tag)

let is_reachable_block me i = 
  i = 0 || idom_of_block me i >= 0

let has_shape = function {shapeo = Some _} -> true | _ -> false
