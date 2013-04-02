(* generated by Ott 0.21.2 from: AilTypesAux_.ott *)
Require Import ZArith.

Require Import Common.
Require Import AilTypes.
Require Import AilTypesAux_fun.
Require Import Implementation.

(** definitions *)

(** funs TypeTransformation *)
Fixpoint pointerConvert (x1:type) : type:=
  match x1 with
  | Void => Void
  | (Basic bt) => (Basic bt)
  |  (Pointer qs ty)  => (Pointer qs ty)
  |  (Array ty n)  => (Pointer  nil  ty)
  |  (Function ty qs_ty_list)  => (Pointer  nil  (Function ty qs_ty_list))
end.

(** definitions *)

(* defns JisInteger *)
Inductive isInteger : type -> Set :=    (* defn isInteger *)
 | IsInteger : forall (it:integerType),
     isInteger (Basic (Integer it)).
(** definitions *)

(* defns JisVoid *)
Inductive isVoid : type -> Prop :=    (* defn isVoid *)
 | IsVoid : 
     isVoid Void.
(** definitions *)

(* defns JisPointer *)
Inductive isPointer : type -> Prop :=    (* defn isPointer *)
 | IsPointer : forall (qs:qualifiers) (ty:type),
     isPointer (Pointer qs ty).
(** definitions *)

(* defns JisBool *)
Inductive isBool : type -> Prop :=    (* defn isBool *)
 | IsBool : 
     isBool (Basic (Integer Bool)).

(* defns JisSigned *)
Inductive isSigned : impl -> integerType -> Prop :=    (* defn isSigned *)
 | IsSignedInt : forall (P:impl) (ibt:integerBaseType),
     isSigned P  (Signed ibt) 
 | IsSignedChar : forall (P:impl),
      Implementation.isCharSigned  P  = true  ->
     isSigned P Char.

Inductive isSignedType : integerType -> Prop :=    (* defn isSigned *)
 | IsSignedType : forall (ibt:integerBaseType),
     isSignedType (Signed ibt).

(* defns JisUnsigned *)
Inductive isUnsigned : impl -> integerType -> Prop :=    (* defn isUnsigned *)
 | IsUnsignedInt : forall (P:impl) (ibt:integerBaseType),
     isUnsigned P (Unsigned ibt)
 | IsUnsignedBool : forall (P:impl),
     isUnsigned P Bool
 | IsUnsignedChar : forall (P:impl),
      ~ (   Implementation.isCharSigned  P  = true   )  ->
     isUnsigned P Char.
(** definitions *)

Inductive isUnsignedType : integerType -> Prop :=    (* defn isUnsigned *)
 | IsUnsignedTypeInt : forall (ibt:integerBaseType),
     isUnsignedType (Unsigned ibt)
 | IsUnsignedTypeBool : isUnsignedType Bool.

(** definitions *)

(* defns JinTypeRange *)
Inductive inIntegerTypeRange : impl -> nat -> integerType -> Prop :=    (* defn inTypeRange *)
 | InIntegerTypeRange : forall (P:impl) (n:nat) (it:integerType),
     memNat  n    (integerTypeRange  P   it )  ->
     inIntegerTypeRange P n it.
(** definitions *)

(* defns JleTypeRange *)
Inductive leIntegerTypeRange : impl -> integerType -> integerType -> Prop :=    (* defn leTypeRange *)
 | LeIntegerTypeRange : forall (P:impl) (it1 it2:integerType),
     le  (integerTypeRange  P   it1 )   (integerTypeRange  P   it2 )  ->
     leIntegerTypeRange P it1 it2.
(** definitions *)

(* defns JeqRank *)
Inductive eqIntegerRankBase : integerType -> integerType -> Prop :=    (* defn eqRank *)
 | EqIntegerRankBaseUnsigned : forall (ibt:integerBaseType),
     eqIntegerRankBase (Signed ibt) (Unsigned ibt)
 | EqIntegerRankBaseUnsignedChar : 
     eqIntegerRankBase Char (Unsigned Ichar)
 | EqIntegerRankBaseSignedChar : 
     eqIntegerRankBase Char (Signed Ichar).

Inductive eqIntegerRank : integerType -> integerType -> Prop :=    (* defn eqRank *)
 | EqIntegerRankBase  : forall it1 it2, eqIntegerRankBase it1 it2 -> eqIntegerRank it1 it2
 | EqIntegerRankSym   : forall it1 it2, eqIntegerRankBase it1 it2 -> eqIntegerRank it2 it1
 | EqIntegerRankRefl  : forall (it:integerType), eqIntegerRank it it.
(** definitions *)

(* defns JltRank *)
Inductive ltIntegerRankBase : impl -> integerType -> integerType -> Prop :=    (* defn ltRank *)
 | LtIntegerRankBasePrecision : forall (P:impl) (ibt1 ibt2:integerBaseType),
      (precision  P   (Signed ibt1)  < precision  P   (Signed ibt2) )%Z  ->
     ltIntegerRankBase P (Signed ibt1) (Signed ibt2)
 | LtIntegerRankBaseBool : forall (P:impl) (it:integerType),
      Bool <> it  ->
     ltIntegerRankBase P Bool it
 | LtIntegerRankBaseLongLong : forall (P:impl),
     ltIntegerRankBase P (Signed Long) (Signed LongLong)
 | LtIntegerRankBaseLong : forall (P:impl),
     ltIntegerRankBase P (Signed Int) (Signed Long)
 | LtIntegerRankBaseInt : forall (P:impl),
     ltIntegerRankBase P (Signed Short) (Signed Int)
 | LtIntegerRankBaseShort : forall (P:impl),
     ltIntegerRankBase P (Signed Ichar) (Signed Short).

Inductive ltIntegerRankCongruence : impl -> integerType -> integerType -> Prop :=
 | LtIntegerRankCongruence :  forall (P:impl) (it1 it2 it1' it2':integerType),
     eqIntegerRank it1 it1' ->
     eqIntegerRank it2 it2' ->
     ltIntegerRankBase P it1 it2 ->
     ltIntegerRankCongruence P it1' it2'.

Inductive ltIntegerRank : impl -> integerType -> integerType -> Prop :=    (* defn ltRank *)
 | LtIntegerRankBase : forall P it1 it2, ltIntegerRankCongruence P it1 it2 -> ltIntegerRank P it1 it2
 | LtIntegerRankTransitive : forall (P:impl) (it1 it2 it:integerType),
     ltIntegerRankCongruence P it1 it ->
     ltIntegerRank P it it2 ->
     ltIntegerRank P it1 it2.
(** definitions *)

(* defns JleRank *)
Inductive leIntegerRank : impl -> integerType -> integerType -> Prop :=    (* defn leRank *)
 | LeIntegerRankEq : forall (P:impl) (it1 it2:integerType),
     eqIntegerRank it1 it2 ->
     leIntegerRank P it1 it2
 | LeIntegerRankLt : forall (P:impl) (it1 it2:integerType),
     ltIntegerRank P it1 it2 ->
     leIntegerRank P it1 it2.
(** definitions *)

(* defns JisArithmetic *)
Inductive isArithmetic : type -> Prop :=    (* defn isArithmetic *)
 | IsArithmeticInteger : forall (ty:type),
     isInteger ty ->
     isArithmetic ty.
(** definitions *)

(* defns JisScalar *)
Inductive isScalar : type -> Prop :=    (* defn isScalar *)
 | IsScalarPointer : forall (ty:type),
     isPointer ty ->
     isScalar ty
 | IsScalarArithmetic : forall (ty:type),
     isArithmetic ty ->
     isScalar ty.
(** definitions *)

(* defns JisArray *)
Inductive isArray : type -> Prop :=    (* defn isArray *)
 | IsArray : forall (ty:type) (n:nat),
     isArray (Array ty n).
(** definitions *)

(* defns JisFunction *)
Inductive isFunction : type -> Prop :=    (* defn isFunction *)
 | IsFunction : forall (ps : params) (ty:type),
     isFunction  (Function ty ps) .
(** definitions *)

(* defns JisUnsignedOf *)
Inductive isCorrespondingUnsigned : integerType -> integerType -> Prop :=    (* defn isCorrespondingUnsigned *)
 | IsCorrespondingUnsigned : forall (ibt:integerBaseType),
     isCorrespondingUnsigned  (Signed ibt)   (Unsigned ibt).
(** definitions *)

(* defns JisPromotion *)
Inductive isIntegerPromotion : impl -> integerType -> integerType -> Prop :=    (* defn isPromotion *)
 | IsPromotionToSignedInt : forall (P:impl) (it:integerType),
      ~ it = Unsigned Int ->
      ~ it = Signed   Int ->
     leIntegerRank P it (Signed Int) ->
     leIntegerTypeRange P it (Signed Int) ->
     isIntegerPromotion P it (Signed Int)
 | IsIntegerPromotionToUnsignedInt : forall (P:impl) (it:integerType),
      ~ it = Unsigned Int ->
      ~ it = Signed   Int ->
     leIntegerRank P it (Signed Int) ->
      ~ leIntegerTypeRange P it (Signed Int) ->
     isIntegerPromotion P it (Unsigned Int)
 | IsIntegerPromotionUnsignedInt : forall (P:impl),
     isIntegerPromotion P (Unsigned Int) (Unsigned Int)
 | IsIntegerPromotionSignedInt : forall (P:impl),
     isIntegerPromotion P (Signed Int) (Signed Int)
 | IsIntegerPromotionRank : forall (P:impl) (it:integerType),
      ~ leIntegerRank P it (Signed Int) ->
     isIntegerPromotion P it it.

(* defns JisUsualArith-metic *)
Inductive isUsualArithmeticInteger : impl -> integerType -> integerType -> integerType -> Prop :=    (* defn isUsualArithmetic *)
 | IsUsualArithmeticIntegerEq : forall (P:impl) (it:integerType),
     isUsualArithmeticInteger P it it it
 | IsUsualArithmeticIntegerGtSameSigned : forall (P:impl) (it1 it2:integerType),
      ~ it1 = it2 ->
      isSignedType it1 ->
      isSignedType it2 ->
     ltIntegerRank P it2 it1 ->
     isUsualArithmeticInteger P it1 it2 it1
 | IsUsualArithmeticIntegerGtSameUnsigned : forall (P:impl) (it1 it2:integerType),
      ~ it1 = it2 ->
      isUnsignedType it1 ->
      isUnsignedType it2 ->
     ltIntegerRank P it2 it1 ->
     isUsualArithmeticInteger P it1 it2 it1
 | IsUsualArithmeticIntegerLtSameSigned : forall (P:impl) (it1 it2:integerType),
      ~ it1 = it2 ->
      isSignedType it1 ->
      isSignedType it2 ->
     ltIntegerRank P it1 it2 ->
     isUsualArithmeticInteger P it1 it2 it2
 | IsUsualArithmeticIntegerLtSameUnsigned : forall (P:impl) (it1 it2:integerType),
      ~ it1 = it2 ->
     isUnsignedType it1 ->
     isUnsignedType it2 ->
     ltIntegerRank P it1 it2 ->
     isUsualArithmeticInteger P it1 it2 it2
 | IsUsualArithmeticIntegerLtUnsigned : forall (P:impl) (it1 it2 :integerType),
      ~ it1 = it2->
     isSignedType   it1 ->
     isUnsignedType it2 ->
     leIntegerRank P it1 it2 ->
     isUsualArithmeticInteger P it1 it2 it2
 | IsUsualArithmeticIntegerGtUnsigned : forall (P:impl) (it1 it2:integerType),
      ~ (   it1  =  it2   )  ->
     isUnsignedType it1 ->
     isSignedType it2 ->
     leIntegerRank P it2 it1 ->
     isUsualArithmeticInteger P it1 it2 it1
 | IsUsualArithmeticIntegerLtSigned : forall (P:impl) (it1 it2:integerType),
      ~ (   it1  =  it2   )  ->
     isUnsignedType it1 ->
     isSignedType it2 ->
     leIntegerRank P it1 it2 ->
     leIntegerTypeRange P it1 it2 ->
     isUsualArithmeticInteger P it1 it2 it2
 | IsUsualArithmeticIntegerGtSigned : forall (P:impl) (it1 it2 :integerType),
      ~ (   it1  =  it2   )  ->
     isSignedType it1 ->
     isUnsignedType it2 ->
     leIntegerRank P it2 it1 ->
     leIntegerTypeRange P it2 it1 ->
     isUsualArithmeticInteger P it1 it2 it1
 | IsUsualArithmeticIntegerLtSigned' : forall (P:impl) (it1 it2 it2':integerType),
      ~ (   it1  =  it2   )  ->
     isUnsignedType it1 ->
     isSignedType it2 ->
     leIntegerRank P it1 it2 ->
      ~ (  leIntegerTypeRange P it1 it2  )  ->
     isCorrespondingUnsigned it2 it2' ->
     isUsualArithmeticInteger P it1 it2 it2'
 | IsUsualArithmeticIntegerGtSigned' : forall (P:impl) (it1 it2 it1':integerType),
      ~ (   it1  =  it2   )  ->
     isSignedType it1 ->
     isUnsignedType it2 ->
     leIntegerRank P it2 it1 ->
      ~ (  leIntegerTypeRange P it2 it1  )  ->
     isCorrespondingUnsigned it1 it1' ->
     isUsualArithmeticInteger P it1 it2 it1'.
(** definitions *)

Inductive isUsualArithmetic (P : impl) : type -> type -> type -> Prop :=
  | IsUsualArithmeticInteger :
      forall (it1 it2 it1' it2' it : integerType),
      isIntegerPromotion P it1 it1' ->
      isIntegerPromotion P it2 it2' ->
      isUsualArithmeticInteger P it1' it2' it ->
      isUsualArithmetic P (Basic (Integer it1)) (Basic (Integer it2)) (Basic (Integer it)).

(* defns JisObject *)
Inductive isObject : type -> Prop :=    (* defn isObject *)
 | IsObjectBasicType : forall (bt:basicType),
     isObject (Basic bt)
 | IsObjectVoid : 
     isObject Void
 | IsObjectPointer : forall (qs:qualifiers) (ty:type),
     isObject  (Pointer qs ty) 
 | IsObjectArray : forall (ty:type) (n:nat),
     isObject  (Array ty n) .
(** definitions *)

(* defns JisComplete *)
Inductive isComplete : type -> Prop :=    (* defn isComplete *)
 | IsCompleteBasicType : forall (bt:basicType),
     isComplete (Basic bt)
 | IsCompletePointer : forall (qs:qualifiers) (ty:type),
     isComplete  (Pointer qs ty) 
 | IsCompleteArray : forall (ty:type) (n:nat),
     isComplete  (Array ty n) .
(** definitions *)

(* defns JisIncomplete *)
Inductive isIncomplete : type -> Prop :=    (* defn isIncomplete *)
 | IsIncompleteVoid : 
     isIncomplete Void.
(** definitions *)

(* defns JisModifiable *)
Inductive isModifiable : qualifiers -> type -> Prop :=    (* defn isModifiable *)
 | IsModifiable : forall (qs:qualifiers) (ty:type),
     isObject ty ->
      ~ (  isArray ty  )  ->
      ~ (  isIncomplete ty  )  ->
      ~ (   (List.In  Const   qs )   )  ->
     isModifiable qs ty.
(** definitions *)

(* defns JisReal *)
Inductive isReal : type -> Prop :=    (* defn isReal *)
 | IsRealInteger : forall (ty:type),
     isInteger ty ->
     isReal ty.
(** definitions *)

(* defns JisLvalueConvertible *)
Inductive isLvalueConvertible : type -> Prop :=    (* defn isLvalueConvertible *)
 | IsLvalueConvertible : forall (ty:type),
      ~ (  isArray ty  )  ->
     isComplete ty ->
     isLvalueConvertible ty.
(** definitions *)

(* defns JisCompatible *)
Inductive isCompatible : type -> type -> Prop :=    (* defn isCompatible *)
 | IsCompatibleEq : forall (ty:type),
     isCompatible ty ty
 | IsCompatibleFunction : forall (p1 p2 : params) (t1 t2 : type),
     isCompatible t1 t2 ->
     isCompatible_params p1 p2 ->
     isCompatible (Function t1 p1) (Function t2 p2)
with isCompatible_params : params -> params -> Prop :=
 | IsCompatible_nil  :
     isCompatible_params ParamsNil ParamsNil
 | IsCompatible_cons : forall qs1 t1 p1 qs2 t2 p2, 
     isCompatible t1 t2 ->
     isCompatible_params p1 p2 ->
     isCompatible_params (ParamsCons qs1 t1 p1) (ParamsCons qs2 t2 p2).

(* defns JisComposite *)
Inductive isComposite : type -> type -> type -> Prop :=    (* defn isComposite *)
 | IsCompositeEq : forall (ty:type),
     isComposite ty ty ty
 | IsCompositeArray : forall (ty1:type) (n:nat) (ty2 ty:type),
     isComposite ty1 ty2 ty ->
     isComposite  (Array ty1 n)   (Array ty2 n)   (Array ty n)
 | IsCompositeFunction : forall (p1 p2 p : params) (t1 t2 t : type),
     isComposite t1 t2 t ->
     isComposite_params p1 p2 p ->
     isComposite (Function t1 p1) (Function t2 p2) (Function t p)
with isComposite_params : params -> params -> params -> Prop :=
 | IsComposite_nil :
     isComposite_params ParamsNil
                        ParamsNil
                        ParamsNil
 | IsComposite_cons : forall t1 p1 qs1 t2 p2 qs2 t3 p3,
     isComposite        t1 t2 t3 ->
     isComposite_params p1 p2 p3 ->
     isComposite_params (ParamsCons qs1 t1 p1)
                        (ParamsCons qs2 t2 p2)
                        (ParamsCons nil t3 p3).
