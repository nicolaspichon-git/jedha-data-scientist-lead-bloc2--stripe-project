```mermaid
flowchart TB
  PAYS[["COUNTRY<br/>#country_code<br/>name<br/>region"]]
  DEVISE[["CURRENCY<br/>#currency_code<br/>name<br/>decimals"]]
  MARCHAND[["MERCHANT<br/>#merchant_id<br/>legal_name<br/>status<br/>created_at"]]
  CLIENT[["CUSTOMER<br/>#customer_id<br/>email<br/>created_at"]]
  MOYEN[["PAYMENT_METHOD<br/>#payment_method_id<br/>type<br/>brand<br/>card_last4<br/>expiry<br/>is_default<br/>created_at"]]
  PRODUIT[["PRODUCT<br/>#product_id<br/>name<br/>unit_price<br/>active<br/>created_at"]]
  TRANSACTION[["TRANSACTION<br/>#transaction_id<br/>amount<br/>created_at<br/>status<br/>ip_geolocation<br/>device_type"]]
  REMB[["REFUND<br/>#refund_id<br/>amount<br/>reason<br/>created_at"]]
  LITIGE[["CHARGEBACK<br/>#chargeback_id<br/>reason_code<br/>status<br/>created_at<br/>resolved_at"]]
  SCORE[["FRAUD_SCORE<br/>#fraud_score_id<br/>anomaly_score<br/>risk_level<br/>model_version<br/>evaluated_at"]]
  PLAN[["PRICING_PLAN<br/>#pricing_plan_id<br/>commission_rate<br/>effective_from<br/>effective_to"]]

  SITUER{IsLocatedIn}
  RESIDER{ResidesIn}
  POSSEDER{Owns}
  CATALOGUER{Catalogs}
  TARIFER{IsPricedIn}
  ENREGISTRER{Registers}
  SOUSCRIRE{"Subscribes<br/><i>status</i><br/><i>billing_cycle</i><br/><i>amount</i><br/><i>started_at</i><br/><i>current_period_end</i><br/><i>canceled_at</i><br/><i>failed_attempt_count</i>"}
  AUTORISER{Authorizes}
  DENOMINATEDIN{IsDenominatedIn}
  BENEFICIER{BenefitsFrom}
  QUOTEDIN{"IsQuotedIn<br/><i>fixed_fee</i>"}
  RECEVOIR{Receives}
  CONCERNER{Bears}
  UTILISER{IsUsedIn}
  REGLER{IsSettledIn}
  FACTURER{IsRatedUnder}
  GENERER{Generates}
  ACHETER{Purchases}
  REMBOURSER{Triggers}
  CONTESTER{Disputes}
  EVALUER{Evaluates}

  MARCHAND ---|"1,1"| SITUER
  SITUER ---|"0,n"| PAYS
  CLIENT ---|"0,1"| RESIDER
  RESIDER ---|"0,n"| PAYS

  MARCHAND ---|"0,n"| POSSEDER
  POSSEDER ---|"1,1"| CLIENT
  MARCHAND ---|"0,n"| CATALOGUER
  CATALOGUER ---|"1,1"| PRODUIT
  PRODUIT ---|"1,1"| TARIFER
  TARIFER ---|"0,n"| DEVISE
  CLIENT ---|"1,n"| ENREGISTRER
  ENREGISTRER ---|"1,1"| MOYEN

  CLIENT ---|"0,n"| SOUSCRIRE
  SOUSCRIRE ---|"0,n"| PRODUIT
  SOUSCRIRE ---|"1,1"| AUTORISER
  AUTORISER ---|"0,n"| MOYEN
  SOUSCRIRE ---|"1,1"| DENOMINATEDIN
  DENOMINATEDIN ---|"0,n"| DEVISE

  MARCHAND ---|"0,n"| BENEFICIER
  BENEFICIER ---|"1,1"| PLAN

  PLAN ---|"0,n"| QUOTEDIN
  QUOTEDIN ---|"0,n"| DEVISE

  MARCHAND ---|"0,n"| RECEVOIR
  RECEVOIR ---|"1,1"| TRANSACTION
  CLIENT ---|"0,n"| CONCERNER
  CONCERNER ---|"1,1"| TRANSACTION
  MOYEN ---|"0,n"| UTILISER
  UTILISER ---|"1,1"| TRANSACTION
  TRANSACTION ---|"1,1"| REGLER
  REGLER ---|"0,n"| DEVISE
  TRANSACTION ---|"1,1"| FACTURER
  FACTURER ---|"0,n"| PLAN

  SOUSCRIRE ---|"0,n"| GENERER
  GENERER ---|"0,1"| TRANSACTION
  TRANSACTION ---|"0,1"| ACHETER
  ACHETER ---|"0,n"| PRODUIT

  TRANSACTION ---|"0,1"| REMBOURSER
  REMBOURSER ---|"1,1"| REMB
  TRANSACTION ---|"0,1"| CONTESTER
  CONTESTER ---|"1,1"| LITIGE
  TRANSACTION ---|"0,1"| EVALUER
  EVALUER ---|"1,1"| SCORE
```
