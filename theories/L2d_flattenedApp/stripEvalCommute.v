
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.Arith.Peano_dec.
Require Import Coq.Setoids.Setoid.
Require Import Omega.

Require Import L2.L2.
Require Import L2d.compile.
Require Import L2d.term.
Require Import L2d.program.
Require Import L2d.wcbvEval.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.

Definition L2Term := L2.compile.Term.
Definition L2Terms := L2.compile.Terms.
Definition L2Brs := L2.compile.Brs.
Definition L2Defs := L2.compile.Defs.


Definition optStrip (t:option L2Term) : option Term :=
  match t with
    | None => None
    | Some t => Some (strip t)
  end.
Definition optStrips (ts:option L2Terms) : option Terms :=
  match ts with
    | None => None
    | Some ts => Some (strips ts)
  end.
Definition optStripDnth (b: option (L2Term * nat)) : option (Term * nat) :=
                           match b with
                             | None => None
                             | Some (t, n) => Some (strip t, n)
                           end.
Definition optStripBnth := optStripDnth.
Function optStripCanP
           (b: option (nat * L2Terms)): option (nat * Terms) :=
                           match b with
                             | None => None
                             | Some (n, t) => Some (n, strips t)
                           end.

Lemma optStrip_hom: forall y, optStrip (Some y) = Some (strip y).
induction y; simpl; reflexivity.
Qed.
Lemma optStrip_hom_None: optStrip (@None L2.compile.Term) = @None (Term).
  reflexivity.
Qed.

Lemma optStrips_hom: forall y, optStrips (Some y) = Some (strips y).
induction y; simpl; reflexivity.
Qed.
Lemma optStripDnth_hom:
  forall y n, optStripDnth (Some (y, n)) = Some (strip y, n).
induction y; simpl; reflexivity.
Qed.
Definition optStripBnth_hom := optStripDnth_hom.
Lemma optStripCanP_hom:
  forall y n, optStripCanP (Some (n, y)) = Some (n, strips y).
induction y; simpl; reflexivity.
Qed.
                              
Lemma tlength_hom:
  forall ts, tlength (strips ts) = L2.term.tlength ts.
Proof.
  induction ts; intros; try reflexivity.
  - cbn. apply f_equal. assumption.
Qed.
  
Lemma Lookup_hom:
  forall p s ec, Lookup s p ec -> Lookup s (stripEnv p) (stripEC ec).
Proof.
  induction 1; destruct t.
  - change (Lookup s ((s, ecTrm (strip l)) :: (stripEnv p))
                   (ecTrm (strip l))).
    apply LHit.
  - cbn. apply LHit.
  - change (Lookup s2 ((s1, ecTrm (strip l)) :: (stripEnv p))
                   (stripEC ec)).
    apply LMiss; assumption.
  - cbn. apply LMiss; assumption.
Qed.

Lemma lookup_hom:
  forall p nm ec,
    lookup nm p = Some ec -> lookup nm (stripEnv p) = Some (stripEC ec).
Proof.
  intros p nm ec h. apply Lookup_lookup.
  apply Lookup_hom. apply (lookup_Lookup _ _ h).
Qed.
  
Lemma lookup_hom_None:
  forall p nm,
    lookup nm p = None -> lookup nm (stripEnv p) = None.
Proof.
  induction p; intros.
  - cbn. reflexivity.
  - destruct a. destruct (string_dec nm s).
    + subst. cbn in H. rewrite string_eq_bool_rfl in H. discriminate.
    + cbn. rewrite (string_eq_bool_neq n).
      cbn in H. rewrite (string_eq_bool_neq n) in H.
      apply IHp. assumption.
Qed.
  
Lemma LookupDfn_hom:
  forall p s t, LookupDfn s p t -> LookupDfn s (stripEnv p) (strip t).
Proof.
  unfold LookupDfn. intros.
  assert (j:= Lookup_hom H). exact j.
Qed.

Lemma lookupDfn_hom:
  forall p nm t,
    lookupDfn nm p = Ret t -> lookupDfn nm (stripEnv p) = Ret (strip t).
Proof.
  induction p; intros.
  - cbn in *. discriminate.
  - destruct a. unfold lookupDfn. cbn. unfold lookupDfn in H. cbn in H.
    destruct (string_dec nm s).
    + subst. cbn. cbn in H.
      rewrite string_eq_bool_rfl. rewrite string_eq_bool_rfl in H.
      destruct e; try discriminate.
      * myInjection H. cbn. reflexivity.
    + rewrite (string_eq_bool_neq n). rewrite (string_eq_bool_neq n) in H.
      case_eq (lookup nm p); intros; rewrite H0 in H; try discriminate.
      * rewrite (lookup_hom _ _ H0). destruct e0; try discriminate.
        cbn. myInjection H. reflexivity.
Qed.

Lemma dlength_hom:
  forall ds, L2.term.dlength ds = dlength (stripDs ds).
induction ds. intuition. simpl. rewrite IHds. reflexivity.
Qed.

Lemma tcons_hom:
  forall t ts, strips (L2.compile.tcons t ts) = tcons (strip t) (strips ts).
reflexivity.
Qed.

Lemma tnil_hom: strips L2.compile.tnil = tnil.
reflexivity.
Qed.

Lemma dcons_hom:
  forall nm bod rarg ds,
    stripDs (L2.compile.dcons nm bod rarg ds) =
    dcons nm (strip bod) rarg (stripDs ds).
reflexivity.
Qed.

Lemma dnil_hom: stripDs L2.compile.dnil = dnil.
reflexivity.
Qed.

Lemma dnthBody_hom:
  forall dts m,
    dnthBody m (stripDs dts) =
    option_map (fun x => strip (fst x)) (L2.term.dnthBody m dts).
Proof.
  induction dts; intros.
  - reflexivity.
  - case_eq m; intros.
    + unfold dnthBody, L2.term.dnthBody. rewrite dcons_hom. 
      reflexivity.
    + rewrite dcons_hom.
      change
        (dnthBody n1 (stripDs dts) =
         option_map (fun x : compile.L2Term * nat => strip (fst x))
                    (L2.term.dnthBody n1 dts)).
      rewrite <- IHdts. reflexivity.
Qed.

Lemma bnth_hom:
  forall m ds, optStripBnth (L2.term.bnth m ds) =
               bnth m (stripBs ds).
induction m; induction ds; try intuition.
- simpl. intuition.
Qed.

Lemma tnth_hom:
  forall ts n, optStrip (L2.term.tnth n ts) = tnth n (strips ts).
induction ts; simpl; intros n; case n; try reflexivity; trivial.
Qed.

Lemma tskipn_hom:
  forall ts n, optStrips (L2.term.tskipn n ts) = tskipn n (strips ts).
induction ts; simpl; intros n; case n; try reflexivity; trivial.
Qed.

Lemma tappend_hom:
  forall ts us,
    strips (L2.compile.tappend ts us) = tappend (strips ts) (strips us).
induction ts; intros us; simpl. reflexivity.
rewrite IHts. reflexivity.
Qed.

Lemma isApp_hom:
  forall t, isApp (strip t) -> L2.term.isApp t.
Proof.
  destruct t; simpl; intros h;
  destruct h as [x0 [x1 h]]; try discriminate. 
  exists t1, t2, t3. reflexivity.
Qed.

(****
Lemma isLambda_hom:
  forall t, isLambda (strip t) -> L2.term.isLambda t.
Proof.
  destruct t; simpl; intros h; destruct h as [x0 [x1 h]]; try discriminate. 
  exists n, t. reflexivity.
Qed.

Lemma isFix_hom:
  forall t, isFix (strip t) -> L2.term.isFix t.
Proof.
  destruct t; cbn; intros h; destruct h as [x0 [x1 h]]; try discriminate.
  exists d, n. reflexivity. 
Qed.

Lemma L1WFapp_L2WFapp:
  (forall t, L2.term.WFapp t -> WFapp (strip t)) /\
  (forall ts, L2.term.WFapps ts -> WFapps (strips ts)) /\
  (forall ts, L2.term.WFappBs ts -> WFappBs (stripBs ts)) /\
  (forall ds, L2.term.WFappDs ds -> WFappDs (stripDs ds)).
Proof.
  apply L2.term.WFappTrmsBrsDefs_ind; simpl; constructor; auto.
  intros h. elim H. apply isApp_hom. assumption.
Qed.

Lemma L1WFaEnv_L2WFaEnv:
  forall p:environ L2Term, L2.program.WFaEnv p -> WFaEnv (stripEnv p).
Proof.
  induction 1; simpl; constructor.
  - inversion H; destruct ec; simpl; try discriminate; constructor.
    + apply (proj1 (L1WFapp_L2WFapp)). assumption.
  - assumption.
  - apply stripEnv_pres_fresh. assumption.
Qed.
 ************)

(***
Lemma WFapp_hom:
  (forall t, L2.term.WFapp t -> WFapp (strip t)) /\
  (forall ts, L2.term.WFapps ts -> WFapps (strips ts)) /\
  (forall ds, L2.term.WFappDs ds -> WFappDs (stripDs ds)).
Proof.
   apply L2.term.WFappTrmsDefs_ind; cbn; intros;
  try (solve [constructor]);
  try (solve [constructor; intuition]).
  - constructor; try assumption.
    + intros h. assert (j:= isApp_hom _ h). contradiction.
Qed.
 ****)

Lemma mkApp_tcons_lem1:
  forall fn arg args,
    mkApp (mkApp fn (tcons arg args)) tnil = mkApp fn (tcons arg args).
Proof.
  destruct fn; intros arg args; simpl;
  try rewrite tappend_tnil; try reflexivity.
Qed.

Lemma TDummy_hom:
  forall str, strip (L2.compile.TDummy str) = TDummy str.
reflexivity.
Qed.

Lemma TApp_hom:
  forall fn arg args,
     strip (L2.compile.TApp fn arg args) =
     mkApp (strip fn) (tcons (strip arg) (strips args)).
Proof.
  destruct fn; intros arg args; try reflexivity.
Qed.

Lemma TApp_Hom:
  forall fn arg args,
    strip (L2.compile.TApp fn arg args) =
    mkApp (strip fn) (tcons (strip arg) (strips args)).
Proof.
  induction fn; intros; try reflexivity.
Qed.

(*********
Variables (i:inductive) (m np na:nat) (v v0 v1 v2:Term).
Compute (canonicalP (TApp (TConstruct i m np na) v)).
(* Some (m, tunit v) *)
Compute (canonicalP (mkApp (TApp (TConstruct i m np na) v)
                           (tunit v0))).
(* Some (m, tcons v0 (tunit v)) *)
Compute (canonicalP (mkApp (TApp (TConstruct i m np na) v)
                           (tcons v1 (tunit v0)))).
(* Some (m, tcons v0 (tcons v1 (tunit v))) *)
Compute (canonicalP (mkApp (TApp (TConstruct i m np na) v)
                           (tcons v2 (tcons v1 (tunit v0))))).
(* Some (m, tcons v0 (tcons v1 (tcons v2 (tunit v)))) *)
 ****************)

Lemma TConstruct_hom:
  forall i n np na,
    strip (L2.compile.TConstruct i n np na) = TConstruct i n np na.
intros. simpl. reflexivity.
Qed.

Lemma canonicalP_mkApp:
  forall vs t, canonicalP (mkApp t vs) =
               match canonicalP t with
               | Some (n, us) => Some (n, (tappend us vs))
               | None => None
               end.
Proof.
  induction vs; intros.
  - cbn. destruct (canonicalP t); try reflexivity.
    destruct p. rewrite tappend_tnil. reflexivity.
  - cbn. rewrite (IHvs (TApp t0 t)). cbn.
    destruct (canonicalP t0); try reflexivity.
    destruct p. apply f_equal. apply f_equal2; try reflexivity.
    rewrite <- tappend_assoc. reflexivity.
Qed.

(*******
Set Template Cast Propositions.
Quote Recursively Definition p0 := (cons I (cons I nil)).
Print p0.
Definition P0 :=
  Eval cbv in (main (L2.compile.program_Program p0)).
Print P0.
Inductive LL:Prop :=
| ZZ:LL
| SS:nat -> LL -> LL.
Quote Recursively Definition p1 := (SS 0 (SS 1 ZZ)).
Print p1.
Definition P1_2 :=
  Eval cbv in (main (L2.compile.program_Program p1)).
Print P1_2.
Definition P1_2d :=
  Eval cbv in (main (L2d.compile.program_Program p1)).
Print P1_2d.
Eval cbv in canonicalP (P1_2d).

Goal
  optStripCanP (L2.term.canonicalP P1_2) = canonicalP (strip P1_2).
Proof.
  unfold optStripCanP. unfold P1_2.
  unfold L2.term.canonicalP. unfold canonicalP. unfold strip. unfold mkApp.
  unfold tappend. unfold strips.
  reflexivity.
Qed.
 ****************)

Lemma canonicalP_Construct:
  forall ts i m np na,
    canonicalP (mkApp (TConstruct i m np na) ts) = Some (m, ts).
Proof.
  induction ts; intros.
  - reflexivity.
  - rewrite canonicalP_mkApp. cbn. reflexivity.
Qed.

Lemma pre_canonicalP_hom:
  forall mch n ts,
  L2.term.canonicalP mch = Some (n, ts) ->
  canonicalP (strip mch) = Some (n, strips ts).
Proof.
  intros mch n ts.
  functional induction (L2.term.canonicalP mch); intros.
  - myInjection H. reflexivity.
  - myInjection H. rewrite TApp_hom. rewrite tcons_hom. rewrite TConstruct_hom.
    rewrite canonicalP_mkApp. cbn. reflexivity.
  - discriminate.
Qed.

Lemma canonicalP_Some:
  forall ts t n us,
    canonicalP t = Some (n, us) ->
    canonicalP (mkApp t ts) = Some (n, tappend us ts).
Proof.
  induction ts; intros.
  - functional inversion H; try reflexivity.
    + cbn. rewrite H4. rewrite H5. rewrite <- tappend_assoc. reflexivity.
  - functional inversion H; subst.
    + cbn.
      change
        (canonicalP (mkApp (TApp (TConstruct _x n _x0 _x1) t) ts) =
         Some (n, tappend (tunit t) ts)).
      eapply IHts. cbn. reflexivity.
    + cbn. pose proof IHts as k0. specialize (k0 _ _ _ H4).
      rewrite <- tappend_assoc. rewrite tappend_tappend_lem.
      rewrite tappend_assoc. erewrite <- IHts.
      * reflexivity.
      * cbn. rewrite H4. reflexivity.
Qed.

Lemma canonicalP_hom:
  forall t, L2.term.WFapp t ->
             optStripCanP (L2.term.canonicalP t) = canonicalP (strip t).
Proof.
  induction 1; intros; try reflexivity; try assumption.
  destruct fn; try (cbn; rewrite canonicalP_mkApp; reflexivity).
  elim H. auto.
Qed.

(***********
Lemma TAppConstruct_hom:
  forall i m np na arg args,
    strip (L2.compile.TApp (L2.compile.TConstruct i m np na) arg args) =
     TConstruct i m np na (tcons (strip arg) (strips args)).
Proof.
  intros. reflexivity.
Qed.
 *************)

Lemma mkApp_hom:
  forall ts t,
    strip (L2.compile.mkApp t ts) = mkApp (strip t) (strips ts).
Proof.
  intros. functional induction (L2.compile.mkApp t ts); try reflexivity.
  - rewrite TApp_hom. rewrite tappend_hom.
    change
      (mkApp (TApp (strip fn) (strip b)) (tappend (strips bs) (strips args)) =
       mkApp (strip (L2.compile.TApp fn b bs)) (strips args)).
    rewrite TApp_hom. rewrite mkApp_idempotent. 
    change
      (mkApp (TApp (strip fn) (strip b))
             (tappend (strips bs) (strips args)) =
       mkApp (strip fn) (tcons (strip b) (tappend (strips bs)
                                                  (strips args)))).
    reflexivity.
Qed.

Lemma instantiate_tappend_commute:
  forall ts us tin n,
    instantiates tin n (tappend ts us) =
    tappend (instantiates tin n ts) (instantiates tin n us).
Proof.
  induction ts; intros.
  - reflexivity.
  - change (tcons (instantiate tin n t) (instantiates tin n (tappend ts us)) =
            tcons (instantiate tin n t) (tappend (instantiates tin n ts)
                                                 (instantiates tin n us))).
    rewrite IHts. reflexivity.
Qed.

Lemma instantiates_tcons_commute:
  forall tin n t ts,
         (instantiates tin n (tcons t ts)) = 
         (tcons (instantiate tin n t) (instantiates tin n ts)).
intros tin n t ts. reflexivity.
Qed.

Lemma instantiates_dcons_commute:
  forall tin n nm t m ds,
         (instantiateDefs tin n (dcons nm t m ds)) = 
         (dcons nm (instantiate tin n t) m (instantiateDefs tin n ds)).
reflexivity.
Qed.

Lemma WcbvEval_mkApp_fn:
  forall p fn fn',
   WcbvEval p fn fn' ->
   forall args s, WcbvEval p (mkApp fn args) s ->
                  WcbvEval p (mkApp fn' args) s.
Proof.
  induction args using treverse_ind; intros.
  - cbn in *. erewrite (proj1 (WcbvEval_single_valued _) _ _ H _ H0). 
    eapply WcbvEval_no_further. eassumption.
  - rewrite mkApp_tl. rewrite mkApp_tl in H0.
    inversion_clear H0.
    + eapply wAppLam; try eassumption. eapply  IHargs. eassumption.
    + eapply wAppFix; try eassumption. eapply IHargs. eassumption.
    + eapply wAppCong; try eassumption. eapply IHargs. eassumption.
Qed.

Lemma WcbvEval_mkApp_step:
  forall p fn s,
    WcbvEval p fn s -> 
    forall args t, WcbvEval p (mkApp s args) t ->
                   WcbvEval p (mkApp fn args) t.
Proof.
  intros p fn s h0.  
  induction args using treverse_ind; intros.
  - cbn in *.
    pose proof (proj1 (WcbvEval_no_further _) _ _ h0) as k.
    rewrite <- (proj1 (WcbvEval_single_valued _) _ _ k _ H). assumption.
  - rewrite mkApp_tl. rewrite mkApp_tl in H. inversion_clear H.
    + eapply wAppLam; try eassumption. eapply IHargs. eassumption.
    + eapply wAppFix; try eassumption. eapply IHargs. eassumption.
    + eapply wAppCong; try eassumption. eapply IHargs. eassumption.
Qed.

(*********
Goal
  forall args p fn s,
    WcbvEval p (mkApp fn args) s ->
      exists u, (WcbvEval p fn u /\ WcbvEval p (mkApp u args) s).
Proof.
  induction args; intros.
  - cbn in *. exists s. intuition.
    eapply (proj1 (WcbvEval_no_further p)). eassumption.
  - cbn in *. destruct (IHargs _ _ _ H) as [x0 [j0x j1x]]. inversion_Clear j0x.
    + exists (TLambda nm bod). intuition.
      Check (IHargs p (TApp (TLambda nm bod) t)).
      eapply IHargs.
    + cbn in *. exists (TLambda nm bod).

Admitted.
************)
      
Lemma WcbvEval_arg_trn:
  forall p s s',
    WcbvEval p s s' -> forall fn arg, s = TApp fn arg ->
    forall arg', WcbvEval p arg arg' -> WcbvEval p (TApp fn arg') s'.
Proof.
  induction 1; intros; try discriminate.
  - myInjection H2. eapply wAppLam; try eassumption.
    rewrite (proj1 (WcbvEval_single_valued p) _ _ H3 _ H0).
    apply (proj1 (WcbvEval_no_further p) _ _ H0).
  - myInjection H2. eapply wAppFix; try eassumption.
    unfold pre_whFixStep in *. eapply IHWcbvEval2. reflexivity. assumption.
  - myInjection H2. eapply wAppCong; try eassumption. 
    rewrite (proj1 (WcbvEval_single_valued p) _ _ H1 _ H3).
    apply (proj1 (WcbvEval_no_further p) _ _ H3).
Qed.

(***********
Lemma WcbvEval_mkApp_fn':
  forall  args p fn t,
    WcbvEval p fn t ->
    forall fn',
      WcbvEval p fn' t ->
      forall s, WcbvEval p (mkApp fn args) s ->
                     WcbvEval p (mkApp fn' args) s.
Proof.
  induction args; intros; cbn in *. 
  - eapply (sv_cor H H0 H1).
  - eapply IHargs. Check (WcbvEval_mkApp_fn ).


  Lemma WcbvEval_mkApp_args_trn:
  forall p args args',
   WcbvEvals p args args' ->
   forall fn s, WcbvEval p (mkApp fn args) s ->
                WcbvEval p (mkApp fn args') s.
Proof.
  induction 1; intros.
  - assumption.
  - cbn. cbn in H1. eapply IHWcbvEvals. eapply WcbvEval_mkApp_fn.






Admitted.
(*******************
  - inversion_Clear H. assumption.
  - inversion_Clear H. cbn. eapply IHargs. assumption.
    cbn in H0. eapply WcbvEval_mkApp_step.
    instantiate (1:= s).
    rewrite mkApp_tl. rewrite mkApp_tl in H0.
    inversion_clear H0.
    + eapply wAppLam; try eassumption. eapply  IHargs. eassumption.
    + eapply wAppFix; try eassumption. eapply IHargs. eassumption.
    + eapply wAppCong; try eassumption. eapply IHargs. eassumption.
Qed.
***************)

Lemma WcbvEval_args_trn:
  forall p args args',
    WcbvEval p args args' -> forall fn s, 
     WcbvEval p (TApp fn args') s ->  WcbvEval p (TApp fn args') s.
Proof.
Admitted.

(***********
Goal  (*** HERE ****)
  forall p args args',
    WcbvEvals p args args' ->
    forall fn fn',
      WcbvEval p fn fn' ->
      forall s, WcbvEval p (mkApp fn args) s ->
                WcbvEval p (mkApp fn' args') s.
Proof.
  induction 1; intros.
  - cbn in *. rewrite (proj1 (WcbvEval_single_valued p) _ _ H _ H0).
    eapply (proj1 (WcbvEval_no_further p)). eapply H0. 
  - pose proof (WcbvEval_mkApp_fn H1 _ H2) as j0.

    admit. eapply WcbvEval_mkApp_fn.
    eapply H1. eapply WcbvEval_mkApp_step. eapply H1. eapply IHWcbvEvals.
    eapply H1.

      cbn. cbn in H2.
    
    eapply (IHWcbvEvals (TApp fn t) _ _ _ H2).
    Grab Existential Variables.
    eapply WcbvEval_mkApp_fn.
    

    Lemma instantiate_mkApp_commute:
  forall tin n fn args,
    instantiate tin n (mkApp fn args) =
    mkApp (instantiate tin n fn) (instantiates tin n args).
Proof.
  intros. functional induction (mkApp fn args).
  - destruct fn; cbn; try reflexivity. 
  - destruct fn; rewrite IHt; cbn; try reflexivity.
Qed.
 *************)
*********************)

Lemma instantiate_hom:
  (forall bod arg n, strip (L2.term.instantiate arg n bod) =
                     instantiate (strip arg) n (strip bod)) /\
  (forall bods arg n, strips (L2.term.instantiates arg n bods) =
                      instantiates (strip arg) n (strips bods)) /\
  (forall brs arg n, stripBs (L2.term.instantiateBrs arg n brs) =
                     instantiateBrs (strip arg) n (stripBs brs)) /\
  (forall ds arg n, stripDs (L2.term.instantiateDefs arg n ds) =
                    instantiateDefs (strip arg) n (stripDs ds)).
Proof.
  apply L2.compile.TrmTrmsBrsDefs_ind; intros; try (simpl; reflexivity);
  try (cbn; rewrite H; reflexivity).
  - simpl. destruct (lt_eq_lt_dec n n0); cbn.
    + destruct s.
      * rewrite (proj1 (nat_compare_gt n0 n)); try omega. cbn. reflexivity.
      * subst. rewrite (proj2 (nat_compare_eq_iff _ _)); trivial.
    + rewrite (proj1 (nat_compare_lt n0 n)); trivial.
  - cbn. rewrite H. rewrite H0. reflexivity.
  - rewrite TApp_hom.
    rewrite instantiate_mkApp_commute.
    change
      (strip (L2.compile.mkApp (L2.term.instantiate arg n t)
                               (L2.compile.tcons
                                  (L2.term.instantiate arg n t0)
                                  (L2.term.instantiates arg n t1))) =
      mkApp (instantiate (strip arg) n (strip t))
             (instantiates (strip arg) n (tcons (strip t0) (strips t1)))).
    rewrite <- H. rewrite instantiates_tcons_commute.
    rewrite <- H0. rewrite <- H1. rewrite mkApp_hom.
    rewrite tcons_hom. reflexivity.
  - change (TCase p (strip (L2.term.instantiate arg n t))
                  (stripBs (L2.term.instantiateBrs arg n b)) =
            (TCase p (instantiate (strip arg) n (strip t))
                   (instantiateBrs (strip arg) n (stripBs b)))).
    rewrite H0. rewrite H. reflexivity.    
  - change (TFix (stripDs (L2.term.instantiateDefs
                             arg (n0 + L2.term.dlength d) d)) n =
            (TFix (instantiateDefs
                     (strip arg) (n0 + dlength (stripDs d)) (stripDs d)) n)).
    rewrite H. rewrite dlength_hom. reflexivity.
  - change (tcons (strip (L2.term.instantiate arg n t))
                  (strips (L2.term.instantiates arg n t0)) =
            tcons (instantiate (strip arg) n (strip t))
                  (instantiates (strip arg) n (strips t0))).
    rewrite H. rewrite H0. reflexivity.
  - change (bcons n (strip (L2.term.instantiate arg n0 t))
                  (stripBs (L2.term.instantiateBrs arg n0 b)) =
            bcons n (instantiate (strip arg) n0 (strip t))
                  (instantiateBrs (strip arg) n0 (stripBs b))).
    rewrite H0. rewrite H. reflexivity.
  - change (dcons n (strip (L2.term.instantiate arg n1 t)) n0
                  (stripDs (L2.term.instantiateDefs arg n1 d)) =
            dcons n (instantiate (strip arg) n1 (strip t)) n0
                  (instantiateDefs (strip arg) n1 (stripDs d))).
    rewrite H0. rewrite H. reflexivity.
Qed.

Lemma whBetaStep_hom:
  forall bod arg args,
    strip (L2.term.whBetaStep bod arg args) =
    mkApp (whBetaStep (strip bod) (strip arg)) (strips args).
Proof.
  intros. unfold L2.term.whBetaStep, whBetaStep.
  rewrite mkApp_hom. rewrite <- (proj1 instantiate_hom). reflexivity.
Qed.

Lemma optStrip_match:
  forall x (f:L2Term -> L2Term) (g:Term -> Term), 
    (forall z, strip (f z) = g (strip z)) ->
    optStrip (match x with Some y => Some (f y) | None => None end) =
    match (optStrip x) with Some y => Some (g y) | None => None end.
induction x; intros f g h; simpl.
- rewrite h; reflexivity.
- reflexivity.
Qed.

Lemma whCaseStep_hom:
  forall n brs ts,
    optStrip (L2.term.whCaseStep n ts brs) =
    whCaseStep n (strips ts) (stripBs brs).
Proof.
  destruct n, brs; intros; simpl; try reflexivity.
  - unfold whCaseStep. cbn. apply f_equal. rewrite mkApp_hom.
    reflexivity.
  - unfold whCaseStep. unfold L2.term.whCaseStep. cbn. 
    rewrite <- bnth_hom. destruct (L2.term.bnth n brs); simpl.
    + destruct p. cbn. rewrite mkApp_hom. reflexivity. 
    + reflexivity.
Qed.

Lemma TFix_hom:
  forall defs n, strip (L2.compile.TFix defs n) = TFix (stripDs defs) n.
reflexivity.
Qed.

Lemma TLambda_hom:
  forall nm bod,
    strip (L2.compile.TLambda nm bod) = TLambda nm (strip bod).
reflexivity.
Qed.

Lemma TLetIn_hom:
  forall nm dfn bod,
    strip (L2.compile.TLetIn nm dfn bod) =
    TLetIn nm (strip dfn) (strip bod).
reflexivity.
Qed.

Lemma TCase_hom:
  forall n mch brs,
    strip (L2.compile.TCase n mch brs) =
    TCase n (strip mch) (stripBs brs).
reflexivity.
Qed.

Lemma fold_left_hom:
forall (F:L2Term -> nat -> L2Term) 
       (stripF:Term -> nat -> Term) (ns:list nat) (t:L2Term),
  (forall (s:L2Term) (n:nat), strip (F s n) = stripF (strip s) n) ->
  strip (fold_left F ns t) = fold_left stripF ns (strip t).
induction ns; intros t h.
- intuition.
- simpl. rewrite IHns.
  + rewrite h. reflexivity.
  + assumption.
Qed.

Lemma pre_whFixStep_hom:
  forall x dts arg args,
    mkApp (pre_whFixStep (strip x) (stripDs dts) (strip arg)) (strips args) =
    strip (L2.term.pre_whFixStep x dts (L2.compile.tcons arg args)).
Proof.
  intros. unfold pre_whFixStep, L2.term.pre_whFixStep.
  rewrite mkApp_hom. rewrite tcons_hom. cbn. eapply f_equal2; try reflexivity.
  erewrite fold_left_hom.
  - rewrite <- dlength_hom. reflexivity.
  - intros. cbn. rewrite (proj1 instantiate_hom). rewrite TFix_hom.
    reflexivity.
Qed.

Lemma optStripCanP_hom':
  forall z, optStripCanP (Some z) =
            Some (fst z, strips (snd z)).
intros. destruct z as [z0 z1]. cbn. reflexivity.
Qed.

Lemma Construct_strip_inv:
  forall i n np na s,
    TConstruct i n np na = strip s ->
    L2.compile.TConstruct i n np na = s.
Proof.
  intros i n. destruct s; simpl; intros h; try discriminate.
  - destruct (isApp_mkApp_TApp (strips t) (strip s1) (strip s2))
      as [x0 [x1 jx]].
    rewrite jx in h. discriminate.
  - myInjection h. reflexivity.
Qed.

Lemma L2_isConstruct_isConstruct:
  forall t, L2.term.isConstruct t -> isConstruct (strip t).
Proof.
  intros t h.
  destruct h as [x0 [x1 [x2 [x3 jx]]]]. subst. cbn.
  exists x0, x1, x2, x3. reflexivity.
Qed.


(**********
Goal
  forall p fn dum,
    WcbvEval p fn dum -> dum = TDummy ->
    forall ts, WcbvEval p (mkApp fn ts) TDummy.
Proof.
  induction 1; intros; try discriminate.
  - 
  - destruct (mkApp_isApp ts fn t) as [y0 [y1 jy]]. rewrite jy.
    eapply wAppDum.
    inversion_Clear H.

Goal
  forall ts fn p,
    WcbvEval p fn TDummy -> WcbvEval p (mkApp fn ts) TDummy.
Proof.
  induction ts; intros.
  - cbn. assumption.
  - destruct (mkApp_isApp ts fn t) as [y0 [y1 jy]]. rewrite jy.
    eapply wAppDum.
    inversion_Clear H.

Lemma WcbvEval_Dummy_inside:    
  forall ts fn p,
    WcbvEval p fn TDummy -> WcbvEval p (mkApp fn ts) TDummy.
Proof.
  induction ts using (wf_ind tlength). intros. destruct ts.
  - cbn. assumption.
  - cbn. eapply H.
    + cbn. omega.
    + eapply wAppDum. assumption.
Qed.
**************)

Lemma WcbvEval_pres_isCanonical:
    forall p fn fn', WcbvEval p fn fn' -> isCanonical fn -> isCanonical fn'.
Proof.
  induction 1; intros; try eassumption; try econstructor;
    try (solve[inversion_Clear H1]).
  - inversion_Clear H0. 
  - inversion_Clear H2. specialize (IHWcbvEval1 H4).
    inversion IHWcbvEval1.
  - inversion_Clear H2. specialize (IHWcbvEval1 H4). inversion IHWcbvEval1.
  - inversion_Clear H2. intuition.
  - inversion_Clear H4.
Qed.


Lemma WcbvEval_mkApp_WcbvEval:
  forall p args s t,
    WcbvEval p (mkApp s args) t -> exists u, WcbvEval p s u.
Proof.
  induction args; intros.
  - rewrite mkApp_tnil in H. exists t. assumption.
  - cbn in *. specialize (IHargs _ _ H). destruct IHargs as [x jx].
    inversion_clear jx.
    + exists (TLambda nm bod). assumption.
    + exists (TFix dts m). assumption.
    + exists fn'. assumption. 
Qed.

Lemma mkApp_isApp:
  forall us t u, isApp (mkApp t (tcons u us)).
Proof.
  induction us; intros.
  - exists t, u. reflexivity.
  - cbn. cbn in IHus. eapply IHus.
Qed.

Lemma isCanonical_eval:
  forall t,
    isCanonical t ->
    forall u us,
      t = mkApp u us ->
      forall p et, WcbvEval p t et -> exists v vs, et = mkApp v vs.
Proof.
  induction 1; intros.
  - functional inversion H; subst. inversion_Clear H0.
    + exists (TConstruct i n np na), tnil. reflexivity.
    + destruct H.
      replace (mkApp (TApp u y) ys) with (mkApp u (tcons y ys)) in H2;
        try reflexivity.
      pose proof (mkApp_isApp ys u y) as k.
      destruct k as [x0 [x1 jx]]. rewrite jx in H2. discriminate.
Admitted.

(***********
Lemma WcbvEval_isLambda_mkApp:
  forall p us eus,
    WcbvEvals p us eus ->
    forall t nm bod, WcbvEval p t (TLambda nm bod) ->
      WcbvEval p (mkApp t us) (mkApp (TLambda nm bod) eus).
Proof.
  induction 1; intros.
  - cbn. assumption.
  - cbn. eapply IHWcbvEvals.
    specialize (IHWcbvEvals t0 et H1 H2 H3). destruct et.
    Check (IHWcbvEvals _ _ _ H2 H3).
    assert (IH := forall t w, IHWcbvEvals t (TRel n) w H2 H3).
    
    eapply (IHWcbvEvals _ _ H1 H2 H3).
  - cbn. destruct et; eapply (IHWcbvEvals H1 H2 H3). ; try not_isn.
    eapply wAppCong; try eassumption.
      try (eapply wAppCong; eassumption; not_isn).
      try not_isLambda.
Qed.
 *****************)

Lemma hom_isCanonical:
  forall Mch, L2.term.isCanonical Mch -> isCanonical (strip Mch).
Proof.
  induction 1; intros.
  - cbn. constructor.
  - change
      (isCanonical (mkApp (TConstruct i n np na)
                          (tcons (strip arg) (strips args)))).
    cbn. eapply canonicalP_isCanonical. rewrite canonicalP_mkApp.
    unfold canonicalP. reflexivity.
Qed.

Lemma hom_tskipn:
  forall m args ts, L2.term.tskipn m args = Some ts ->
                    tskipn m (strips args) = Some (strips ts).
Proof.
  intros. rewrite <- tskipn_hom. rewrite <- optStrips_hom. rewrite H.
  reflexivity.
Qed.

Lemma mkApp_goodFn:
  forall fn arg args,
    ~ L2.term.isApp fn ->
    strip (L2.compile.mkApp fn (L2.compile.tcons arg args)) =
    strip (L2.compile.TApp fn arg args).
Proof.
  destruct fn; intros; try reflexivity.
  cbn. destruct H. exists fn1, fn2, t. reflexivity.
Qed.

(****************
Lemma WcbvEval_hom:
  forall (p:L2Env) (h:L2.program.WFaEnv p),
    (forall t t', L2.wcbvEval.WcbvEval p t t' -> L2.term.WFapp t ->
                  WcbvEval (stripEnv p) (strip t) (strip t')) /\
    (forall ts ts', L2.wcbvEval.WcbvEvals p ts ts' -> L2.term.WFapps ts ->
                    WcbvEvals (stripEnv p) (strips ts) (strips ts')).
Proof.
  intros p h.
  apply L2.wcbvEval.WcbvEvalEvals_ind; intros; try reflexivity;
  try (solve[constructor; trivial]).
  - cbn. econstructor; try eassumption. eapply H.
    inversion_Clear H0. assumption.
  - cbn. econstructor; try eassumption.
    + apply lookupDfn_hom. eassumption.
    + eapply H. apply (L2.program.lookupDfn_pres_WFapp h _ e).
  - (* beta step in L2 *)
    inversion_Clear H2. rewrite TApp_hom.
    specialize (H H7). specialize (H0 H8).
    rewrite whBetaStep_hom in H1.
    pose proof (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h) _ _ w H7) as k.
    inversion_Clear k.
    pose proof (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h) _ _ w0 H8) as k.
    specialize (H1 (L2.term.whBetaStep_pres_WFapp H3 k H9)). 
    destruct (WcbvEval_mkApp_WcbvEval _ _ H1) as [y jy].
    change
      (WcbvEval (stripEnv p)
                (mkApp (TApp (strip fn) (strip a1)) (strips args))
                (strip s)).
    eapply WcbvEval_mkApp_step.
    + eapply wAppLam; eassumption.
    + eapply WcbvEval_mkApp_fn; eassumption. 
  - inversion_Clear H1. cbn. eapply wLetIn.
    + apply H.  assumption.
    + rewrite <- (proj1 instantiate_hom). apply H0.
      eapply (proj1 (L2.term.instantiate_pres_WFapp)). eassumption.
      eapply (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h) _ _ w). 
      assumption.
  - (** Fix **)
    inversion_Clear H1. specialize (H H6).
    pose proof (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h) _ _ w H6) as k.
    inversion_Clear k. rewrite TApp_hom.
    cbn. rewrite TFix_hom in H. eapply (WcbvEval_mkApp_step).
    admit. admit.
    (*************
    + eapply wAppFix.
      * rewrite TFix_hom in H. eassumption.
      * rewrite dnthBody_hom. rewrite e. reflexivity.
      * cbn. rewrite <- pre_whFixStep_hom in H0.
        Check (WcbvEval_mkApp_step _ _ H0).

       
        .

        Check WcbvEval_mkApp_fn. eapply H0.

    rewrite TFix_hom in H.
    rewrite <- pre_whFixStep_hom in H0. rewrite TApp_hom.
    cbn. eapply WcbvEval_mkApp_step.
    + eapply wAppFix; try eassumption.
      * rewrite dnthBody_hom. rewrite e. reflexivity.
      * Check WcbvEval_mkApp_fn. eapply H0.
    + eapply WcbvEval_mkApp_fn; eassumption.

      
    change (WcbvEval (stripEnv p) (strip fn) (TFix (stripDs dts) m)) in H.

    
    assert (j0: L2.term.wfApp (L2.compile.TFix (stripDs dts) m)).
    assert (j0: WFappDs dts).
    {  (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h) _ _ w H6). }
  
    assert (j: WFapp (L2.term.pre_whFixStep x dts (L2.compile.tcons arg args))).
    { apply (L2.term.pre_whFixStep_pres_WFapp).
      - eapply (L2.term.dnthBody_pres_WFapp); try eassumption.
    destruct (WcbvEval_mkApp_WcbvEval _ _ H0) as [y jy].
    assert (j: dnthBody m (stripDs dts) = Some (strip x)).
    { rewrite dnthBody_hom. rewrite e. cbn. reflexivity. }
    rewrite TApp_Hom. cbn. eapply WcbvEval_mkApp_step.
    + eapply wAppFix; eassumption. 
    + eapply WcbvEval_mkApp_fn; eassumption.
****************)
  - (** congruence **)
    inversion_Clear H2.
    specialize (H H7). specialize (H0 H8). specialize (H1 H9).
    rewrite TApp_hom. rewrite TApp_hom. cbn.
      Check (WcbvEval_mkApp_fn H).
      Check (WcbvEval_mkApp_step H).    
    destruct o.
    + destruct H2 as [x0 [x1 [x2 [x3 jx]]]]; subst.
      cbn in H.
      Check (WcbvEval_mkApp_fn H).
      Check (WcbvEval_mkApp_step H).
      admit.
      (************
      rewrite mkApp_goodFn. rewrite mkApp_goodFn.
      * eapply wAppCong; try eassumption. left. cbn. auto.
      * not_isApp.
      * intros k. elim H6. destruct k as [y0 [y1 [y2 jy]]].
        functional inversion jy. subst. auto.
       *****************)
    + destruct H2 as [x0 jx]. subst.
      cbn in H.
      Check (mkApp_goodFn _ _ H6).
      Check (WcbvEval_mkApp_fn H (tcons (strip arg) (strips args))).
      Check (WcbvEval_mkApp_step H (tcons (strip arg) (strips args))).    

      rewrite mkApp_goodFn. rewrite mkApp_goodFn. cbn.
      eapply wAppCong; try eassumption. 
      * right.    (** ??????  ****)
        exists (String
                  "I" (String
                         "n" (String "d" (String ":" (print_inductive x0))))).
        reflexivity.
      * cbn. not_isApp.
      * intros k. elim H6. destruct k as [y0 [y1 [y2 jy]]].
        functional inversion jy. subst. auto.

    
  - inversion_Clear H1. specialize (H H4).
    assert (p0: L2.term.WFapp Mch).
    { eapply (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h)); eassumption. }
    rewrite TCase_hom. refine (wCase _ _ _ _ _ _ _); try eassumption.
    + rewrite <- canonicalP_hom. rewrite e. reflexivity.
      eapply (proj1 (L2.wcbvEval.WcbvEval_pres_WFapp h)); eassumption.
    + rewrite <- tskipn_hom. rewrite e0. reflexivity.
    + rewrite <- whCaseStep_hom. rewrite e1. reflexivity.
    + apply H0. eapply (L2.term.whCaseStep_pres_WFapp); try eassumption.
      eapply (L2.term.tskipn_pres_WFapp); try eassumption.
      eapply (L2.term.canonicalP_pres_WFapp); try eassumption.
  - inversion_Clear H1. specialize (H H4). specialize (H0 H5).
    rewrite tcons_hom. rewrite tcons_hom. econstructor; eassumption.
Qed.

    
  - (* Fix in L2 *)
    rewrite <- pre_whFixStep_hom in H0.
    change (WcbvEval (stripEnv p) (strip fn) (TFix (stripDs dts) m)) in H.
    destruct (WcbvEval_mkApp_WcbvEval _ _ H0) as [y jy].
    assert (j: dnthBody m (stripDs dts) = Some (strip x)).
    { rewrite dnthBody_hom. rewrite e. cbn. reflexivity. }
    rewrite TApp_Hom. cbn. eapply WcbvEval_mkApp_step.
    + eapply wAppFix; eassumption. 
    + eapply WcbvEval_mkApp_fn; eassumption.
  - destruct o.
    + destruct H2 as [x0 [x1 [x2 [x3 jx]]]]. subst. cbn in H.
      rewrite TApp_hom. rewrite TApp_hom. rewrite TConstruct_hom.
      apply (WcbvEval_mkApp_step H). rewrite tcons_hom. rewrite tcons_hom.
      eapply WcbvEval_mkApp; try eassumption.
      econstructor; try eassumption. eapply wConstruct.
      not_isLambda. not_isFix.
    + subst. cbn in H. rewrite TApp_hom. rewrite TApp_hom.
      apply (WcbvEval_mkApp_step H). 
      rewrite tcons_hom. rewrite tcons_hom.
      eapply WcbvEval_mkApp; try eassumption.
      econstructor; try eassumption.
      eapply (proj1 (WcbvEval_no_further (stripEnv p))).
      eassumption.
      * destruct H2 as [x0 jx]. subst. not_isLambda.
      * destruct H2 as [x0 jx]. subst. not_isFix.
  - rewrite TCase_hom. refine (wCase _ _ _ _ _ _ _); try eassumption.
    + rewrite <- canonicalP_hom. rewrite e. reflexivity.
    + rewrite <- tskipn_hom. rewrite e0. reflexivity.
    + rewrite <- whCaseStep_hom. rewrite e1. reflexivity.


  (***********
  - rewrite TCase_hom. refine (wCase _ _ _ _ _ _ _); try eassumption.
    + rewrite <- canonicalP_hom. rewrite e. reflexivity.
    + rewrite <- tskipn_hom. rewrite e0. reflexivity.
    + rewrite <- whCaseStep_hom. rewrite e1. reflexivity.
         *************)
  -
Qed.
Print Assumptions WcbvEval_hom.

  - 
  - rewrite TCase_hom. refine (wCase _ _ _ _ _ _ _); try eassumption.
  - pose proof (L2.term.canonicalP_isCanonical _ e) as k0.
    pose proof (hom_isCanonical k0) as k1.
    destruct (isCanonical_canonicalP k1) as [x0 [x1 jx]].
    rewrite TCase_hom. refine (wCase _ _ _ _ _ _ _).
    + eassumption.
    + eassumption.
    + Check (hom_tskipn _ _ e0).
    + destruct ml. cbn. cbn in e0. rewrite <- tskipn_hom. rewrite e0. reflexivity.
    + rewrite <- whCaseStep_hom. rewrite e1. reflexivity.
Qed.
Print Assumptions WcbvEval_hom.

L2.term.isCanonical Mch -> isCanonical (strip Mch)
L2.term.canonicalP Mch = Some (n, args) -> isCanonical (strip Mch).

    + rewrite <- canonicalP_hom. rewrite e. reflexivity.


      eapply (WcbvEval_mkApp_fn H). rewrite mkApp_goodFn at 2.
      
  - change
      (WcbvEval (stripEnv p) (strip (L2.compile.TApp fn arg args)) (strip s)).
    change
      (WcbvEval (stripEnv p)
                (mkApp (strip fn) (tcons (strip arg) (strips args)))
                (strip s)).
    change
      (WcbvEval (stripEnv p) (strip fn) (strip (L2.compile.TFix dts m))) in H.
    change
      (WcbvEval (stripEnv p) (strip fn) (TFix (stripDs dts) m)) in H.


    cbn. eapply wAppFix.
    + eapply H.
    + rewrite <- dnthBody_hom. rewrite e. reflexivity.
    + rewrite <- pre_whFixStep_hom in H0. eapply H0.
  - cbn. eapply wAppCong; try eassumption. destruct o.
    + left. apply (proj1 (L2_isConstruct_isConstruct _)). assumption.
    + right. apply L2_isInd_isInd. assumption.    
  - refine (wCase _ _ _ _ _ _ _); try eassumption.
    * rewrite <- canonicalP_hom. rewrite e. reflexivity.
    * rewrite <- tskipn_hom. rewrite e0. reflexivity.
    * rewrite <- whCaseStep_hom. rewrite e1. reflexivity.
Qed.
Print Assumptions WcbvEval_hom.

(** WcbvEval_hom is nice, but it is stronger than necessary to prove 
*** certiL2_to_L2Correct (in instances.v).
**)
Corollary strip_pres_eval:
  forall (p:environ L2.compile.Term) (t tv:L2.compile.Term),
    L2.wcbvEval.WcbvEval p t tv ->
    exists stv, WcbvEval (stripEnv p) (strip t) stv.
Proof.
  intros. exists (strip tv). apply (proj1 (WcbvEval_hom _)).
  assumption.
Qed.

Corollary wcbvEval_hom:
  forall p n t t',
    L2.wcbvEval.wcbvEval p n t = Ret t' ->
    exists m, wcbvEval (stripEnv p) m (strip t) = Ret (strip t').
Proof.
  intros. 
  assert (j1:= proj1 (L2.wcbvEval.wcbvEval_WcbvEval p n) _ _ H).
  assert (k0:= proj1 (WcbvEval_hom p) _ _ j1).
  assert (j2:= @WcbvEval_wcbvEval (stripEnv p) (strip t) (strip t') k0).
  destruct j2 as [ny jny].
  exists ny. eapply jny. omega.
Qed.


Lemma Prf_strip_inv:
  forall s st, TProof st = strip s ->
              exists t, s = L2.compile.TProof t /\ st = strip t.
Proof.
  destruct s; simpl; intros h; try discriminate.
  intros. myInjection H. exists s. intuition.
Qed.
  
Lemma Lam_strip_inv:
  forall nm bod s, TLambda nm bod = strip s ->
   exists sty sbod, 
     (L2.compile.TLambda nm sty sbod) = s /\ bod = strip sbod.
Proof.
  intros nm bod; destruct s; simpl; intros h; try discriminate.
  - myInjection h. exists s1, s2. intuition. 
Qed.

Lemma Const_strip_inv:
  forall nm s, TConst nm = strip s -> L2.compile.TConst nm = s.
Proof.
  intros nm. destruct s; simpl; intros h; try discriminate.
  - myInjection h. reflexivity.
Qed.

Lemma Fix_strip_inv:
  forall ds n s, TFix ds n = strip s ->
    exists sds, (L2.compile.TFix sds n) = s /\ ds = stripDs sds.
Proof.
  intros ds n. destruct s; simpl; intros h; try discriminate.
  - myInjection h. exists d. intuition.
Qed.

Lemma App_strip_inv:
  forall fn arg args s, TApp fn arg args = strip s ->
    exists sfn sarg sargs,
      (L2.compile.TApp sfn sarg sargs) = s /\
      fn = strip sfn /\ arg = strip sarg /\ args = strips sargs.
Proof.
  intros fn arg args. destruct s; simpl; intros h; try discriminate.
  - myInjection h. exists s1, s2, t. intuition.
Qed.

Lemma LetIn_strip_inv:
  forall nm dfn bod s, TLetIn nm dfn bod = strip s ->
    exists sdfn sty sbod,
      (L2.compile.TLetIn nm sdfn sty sbod = s) /\
      dfn = strip sdfn /\ bod = strip sbod.
Proof.
  intros nm dfn bod s. destruct s; simpl; intros h; try discriminate.
  - myInjection h. exists s1, s2, s3. intuition.
Qed.

Lemma Case_strip_inv:
  forall m mch brs s, TCase m mch brs = strip s ->
    exists sty smch sbrs, (L2.compile.TCase m sty smch sbrs = s) /\
              mch = strip smch /\ brs = stripBs sbrs.
Proof.
  intros m mch brs s. destruct s; simpl; intros h; try discriminate.
  - myInjection h. exists s1, s2, b. intuition.
Qed.

Lemma tnil_strip_inv:
  forall ts, tnil = strips ts -> ts = L2.compile.tnil.
Proof.
  induction ts; intros; try reflexivity.
  - simpl in H. discriminate.
Qed.

Lemma tcons_strip_inv:
  forall t ts us, tcons t ts = strips us ->
    exists st sts, (L2.compile.tcons st sts = us) /\ 
                   t = strip st /\ ts = strips sts.
Proof.
  intros t ts us. destruct us; simpl; intros h; try discriminate.
  - myInjection h. exists t0, us. intuition.
Qed.

Lemma dcons_strip_inv:
  forall nm t m ts us, dcons nm t m ts = stripDs us ->
    exists ty st sts, (L2.compile.dcons nm ty st m sts = us) /\ 
                   t = strip st /\ ts = stripDs sts.
Proof.
  intros nm t m ts us. destruct us; simpl; intros h; try discriminate.
  - myInjection h. exists t0, t1, us. intuition.
Qed.

Lemma whCaseStep_Hom:
  forall n ts bs t,
    L2.term.whCaseStep n ts bs = Some t -> 
    whCaseStep n (strips ts) (stripBs bs) = Some (strip t).
Proof.
  intros n ts bs t h. rewrite <- whCaseStep_hom. rewrite <- optStrip_hom.
  apply f_equal. assumption.
Qed.

Definition excStrip (t:exception L2Term) : exception Term :=
  match t with
    | Exc str => Exc str
    | Ret t => Ret (strip t)
  end.


Theorem L2WcbvEval_sound_for_L2WcbvEval:
  forall (p:environ L2.compile.Term) (t:L2.compile.Term) (L2s:Term),
    WcbvEval (stripEnv p) (strip t) L2s ->
  forall s, L2.wcbvEval.WcbvEval p t s -> L2s = strip s.
Proof.
  intros. refine (WcbvEval_single_valued _ _).
  - eassumption.
  - apply WcbvEval_hom. assumption.
Qed.
Print Assumptions L2WcbvEval_sound_for_L2WcbvEval.

(******
Theorem L2WcbvEval_sound_for_L2wndEval:
  forall p t s, WcbvEval (stripEnv p) (strip t) (strip s) ->
           L2.program.WFaEnv p -> L2.term.WFapp t ->        
        L2.wndEval.wndEvalRTC p t s.
Proof.
  intros.
  refine (proj1 (L2.wcbvEval.WcbvEval_wndEvalRTC _) _ _ _ _);
    try assumption.
  
Qed.
Print Assumptions L2WcbvEval_sound_for_L2wndEval.
 *****************)

Theorem L2WcbvEval_sound_for_L2wndEval:
  forall (p:environ L2.compile.Term) (t:L2.compile.Term) (L2s:Term),
    WcbvEval (stripEnv p) (strip t) L2s ->
    forall s, L2.wcbvEval.WcbvEval p t s ->
              L2.program.WFaEnv p -> L2.term.WFapp t ->        
              L2.wndEval.wndEvalRTC p t s.
Proof.
  intros.
  refine (proj1 (L2.wcbvEval.WcbvEval_wndEvalRTC _) _ _ _ _); assumption.
Qed.
Print Assumptions L2WcbvEval_sound_for_L2wndEval.

(*****
Parameter ObsCrct: Term -> L2.compile.Term -> Prop.
Goal
  forall (sp:environ L2.compile.Term) (st:L2.compile.Term),
   (exists ou:Term, WcbvEval (stripEnv sp) (strip st) ou ->
       exists su, L2.wcbvEval.WcbvEval sp st su /\ ObsCrct ou su) /\
(forall (su:L2.compile.Term),
  L2.wcbvEval.WcbvEval sp st su ->
    exists ou:Term, WcbvEval (stripEnv sp) (strip st) ou).
Proof.
  split; intros. Focus 2.
*******************)
  


    
Lemma sound_and_complete:
  forall (p:environ L2.compile.Term) (t s:L2.compile.Term),
    L2.wcbvEval.WcbvEval p t s ->
    WcbvEval (stripEnv p) (strip t) (strip s).
Proof.
  intros p t s h. apply (proj1 (WcbvEval_hom p)). assumption.
Qed.

Lemma sac_complete:
  forall p t s, L2.wcbvEval.WcbvEval p t s ->
                WcbvEval (stripEnv p) (strip t) (strip s).
Proof.
  intros. apply sound_and_complete. assumption.
Qed.

Lemma sac_sound:
  forall p t s, L2.wcbvEval.WcbvEval p t s ->
  forall L2s, WcbvEval (stripEnv p) (strip t) L2s -> L2s = strip s.
Proof.
  intros p t s h1 L2s h2.
  apply (WcbvEval_single_valued h2). apply (sound_and_complete h1).
Qed. 
Print Assumptions sac_sound.

*********************)