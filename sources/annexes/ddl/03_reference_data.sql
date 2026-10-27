-- =====================================================================
-- STRIPE PROJECT - Annexe 1.B (OLTP) - jeu de référence minimal : 03_reference_data.sql
-- Version : v36. Exemple d'amorçage des tables de référence (idempotent). Les listes « vivantes »
-- (CardNetwork, CardNetworkPolicy, ChargebackReasonCode, Currency, Country) sont à alimenter depuis les sources normatives (ISO, réseaux).
-- =====================================================================
INSERT INTO AuditActorType (actor_type_code, label, is_human) VALUES
  ('user','Utilisateur authentifié',true),('service','Service applicatif',false),
  ('system','Processus système',false),('merchant_api','Appel via l''interface marchand',NULL)
ON CONFLICT DO NOTHING;

INSERT INTO AuditAction (action_code, label, is_sensitive, requires_justification) VALUES
  ('read','Consultation',false,false),('export','Export',true,true),('login','Connexion',false,false),
  ('create','Création',true,false),('update','Modification',true,false),('delete','Suppression',true,false),
  ('grant','Octroi de droit',true,true),('revoke','Retrait de droit',true,true)
ON CONFLICT DO NOTHING;

INSERT INTO Country (country_code, name, region) VALUES
  ('FR','France','EMEA'),('DE','Allemagne','EMEA'),('US','États-Unis','AMER'),('JP','Japon','APAC')
ON CONFLICT DO NOTHING;

INSERT INTO Currency (currency_code, name, decimals) VALUES
  ('EUR','Euro',2),('USD','Dollar américain',2),('GBP','Livre sterling',2),('JPY','Yen',0),('BHD','Dinar bahreïni',3)
ON CONFLICT DO NOTHING;

INSERT INTO MerchantStatus (status_code, label, can_process_payments, sort_order) VALUES
  ('active','Actif',true,1),('suspended','Suspendu',false,2),('closed','Clos',false,3)
ON CONFLICT DO NOTHING;

INSERT INTO PaymentMethodType (type_code, label, requires_card_details, sort_order) VALUES
  ('card','Carte',true,1),('bank_transfer','Virement',false,2),('wallet','Portefeuille',false,3),('direct_debit','Prélèvement',false,4)
ON CONFLICT DO NOTHING;

INSERT INTO CardNetwork (network_code, label) VALUES
  ('visa','Visa'),('mastercard','Mastercard'),('amex','American Express'),('discover','Discover')
ON CONFLICT DO NOTHING;

-- délais de réponse aux litiges : valeurs d'exemple, à remplacer par celles des règles des réseaux
INSERT INTO CardNetworkPolicy (network_code, response_deadline_days) VALUES
  ('visa',30),('mastercard',45),('amex',20)
ON CONFLICT DO NOTHING;   -- discover : volontairement sans politique (due_at NULL)

INSERT INTO SubscriptionStatus (status_code, label, is_billable, is_terminal, triggers_dunning, sort_order) VALUES
  ('active','Actif',true,false,false,1),('paused','En pause',false,false,false,2),
  ('past_due','Impayé',true,false,true,3),('canceled','Résilié',false,true,false,4)
ON CONFLICT DO NOTHING;

INSERT INTO TransactionStatus (status_code, label, is_terminal, allows_refund, sort_order) VALUES
  ('pending','En attente',false,false,1),('suspended','Suspendue',false,false,2),('failed','Échouée',true,false,3),
  ('successful','Réussie',false,true,4),('refunded','Remboursée',true,false,5)
ON CONFLICT DO NOTHING;

INSERT INTO ChargebackStatus (status_code, label, is_terminal, sort_order) VALUES
  ('open','Ouvert',false,1),('won','Gagné',true,2),('lost','Perdu',true,3)
ON CONFLICT DO NOTHING;

INSERT INTO ChargebackReasonCode (reason_code, network_code, label, category) VALUES
  ('V-10.4','visa','Fraude - carte absente (exemple)','fraud'),
  ('V-13.1','visa','Service non reçu (exemple)','consumer_dispute'),
  ('M-4837','mastercard','Fraude - transaction non autorisée (exemple)','fraud')
ON CONFLICT DO NOTHING;

INSERT INTO FraudRiskLevel (risk_level_code, label, requires_manual_review, blocks_transaction, sort_order) VALUES
  ('low','Faible',false,false,1),('medium','Moyen',true,false,2),('high','Élevé',true,true,3)
ON CONFLICT DO NOTHING;

INSERT INTO Regulation (regulation_code, label, response_deadline_days) VALUES
  ('GDPR','RGPD (1 mois, approximé à 30 j)',30),('CCPA','CCPA (45 j)',45)
ON CONFLICT DO NOTHING;

INSERT INTO DataSubjectRequestStatus (status_code, label, is_terminal, sort_order) VALUES
  ('received','Reçue',false,1),('in_progress','En cours',false,2),('fulfilled','Satisfaite',true,3),('rejected','Rejetée',true,4)
ON CONFLICT DO NOTHING;

INSERT INTO SecurityIncidentStatus (status_code, label, is_terminal, sort_order) VALUES
  ('open','Ouvert',false,1),('investigating','En investigation',false,2),('contained','Contenu',false,3),('closed','Clos',true,4)
ON CONFLICT DO NOTHING;
