import AssocList "mo:base/AssocList";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Vector "mo:vector";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Float "mo:base/Float";

import RxDbTable = "./db";

actor WalletDatabase {
  type BankDetails = {
    bpi : ?{ accountName : Text; accountNumber : Text };
    gcash : ?Text;
    paymaya : ?Text;
  };

  type PaymentMethodDetails = {
    accountName : ?Text;
    accountNumber : ?Text;
    bankName : ?Text;
    walletAddress : ?Text;
  };

  type PaymentMethod = {
    details : PaymentMethodDetails;
    id : Text;
    methodType : Text;
    name : Text;
  };

  type OrderDocument = {
    amount : Float;
    createdAt : Int;
    deleted : Bool;
    escrowId : ?Text;
    expiresAt : Int;
    id : Text;
    paymentMethod : PaymentMethod;
    price : Float;
    sellerId : Text;
    status : Text;
    updatedAt : Nat32;
  };

  type PaymentVerificationDocument = {
    deleted : Bool;
    orderId : Text;
    proof : ?Text;
    status : Text;
    updatedAt : Nat32;
    verifiedAt : ?Int;
    verifiedBy : ?Text;
  };

  type KYCDocument = {
    address : {
      city : Text;
      country : Text;
      postalCode : Text;
      state : Text;
      street : Text;
    };
    bankDetails : ?BankDetails;
    deleted : Bool;
    documents : [{
      expiryDate : Text;
      fileUrl : Text;
      number : Text;
      type_ : Text;
      verificationStatus : Text;
    }];
    personalInfo : {
      dateOfBirth : Text;
      email : Text;
      firstName : Text;
      lastName : Text;
      nationality : Text;
      phoneNumber : Text;
    };
    riskLevel : Text;
    status : Text;
    updatedAt : Nat32;
    userId : Text;
    verificationDetails : ?{
      remarks : ?Text;
      submittedAt : Int;
      verifiedAt : ?Int;
      verifiedBy : ?Text;
    };
  };

  type ValidatorDocument = {
    avatarUrl : ?Text;
    deleted : Bool;
    id : Text;
    isActive : Bool;
    name : Text;
    rating : Float;
    responseTime : Text;
    totalOrders : Nat;
    updatedAt : Nat32;
  };

  type AssetDocument_v0 = {
    sortIndex : Nat32;
    updatedAt : Nat32;
    deleted : Bool;
    address : Text;
    symbol : Text;
    name : Text;
    tokenName : Text;
    tokenSymbol : Text;
    decimal : Text;
    shortDecimal : Text;
    subAccounts : [{
      name : Text;
      sub_account_id : Text;
      address : Text;
      amount : Text;
      currency_amount : Text;
      transaction_fee : Text;
      decimal : Nat32;
      symbol : Text;
    }];
    index : Text;
    logo : Text;
    supportedStandards : [Text];
  };

  type ContactDocument_v0 = {
    name : Text;
    principal : Text;
    accountIdentifier : Text;
    accounts : [{
      name : Text;
      subaccount : Text;
      subaccountId : Text;
      tokenSymbol : Text;
    }];
    updatedAt : Nat32;
    deleted : Bool;
  };

  type AllowanceDocument_v0 = {
    asset : {
      logo : Text;
      name : Text;
      symbol : Text;
      address : Text;
      decimal : Text;
      tokenName : Text;
      tokenSymbol : Text;
      supportedStandards : [Text];
    };
    id : Text;
    subAccountId : Text;
    spender : Text;
    updatedAt : Nat32;
    deleted : Bool;
  };

  type ServiceDocument_v0 = {
    name : Text;
    principal : Text;
    assets : [{
      tokenSymbol : Text;
      logo : Text;
      tokenName : Text;
      decimal : Text;
      shortDecimal : Text;
      principal : Text;
    }];
    updatedAt : Nat32;
    deleted : Bool;
  };

  type StableStorage = {
    assets : RxDbTable.DbInit<AssetDocument_v0, Text>;
    contacts : RxDbTable.DbInit<ContactDocument_v0, Text>;
    allowances : RxDbTable.DbInit<AllowanceDocument_v0, Text>;
    services : RxDbTable.DbInit<ServiceDocument_v0, Text>;
    orders : RxDbTable.DbInit<OrderDocument, Text>;
    paymentVerifications : RxDbTable.DbInit<PaymentVerificationDocument, Text>;
    kycDetails : RxDbTable.DbInit<KYCDocument, Text>;
    validators : RxDbTable.DbInit<ValidatorDocument, Text>;
  };

  stable var storage_v0 : StableStorage = {
    assets = RxDbTable.empty();
    contacts = RxDbTable.empty();
    allowances = RxDbTable.empty();
    services = RxDbTable.empty();
    orders = RxDbTable.empty();
    paymentVerifications = RxDbTable.empty();
    kycDetails = RxDbTable.empty();
    validators = RxDbTable.empty();
  };

  type AssetDocument = AssetDocument_v0;
  type ContactDocument = ContactDocument_v0;
  type AllowanceDocument = AllowanceDocument_v0;
  type ServiceDocument = ServiceDocument_v0;

  var databasesCache = {
    assets = RxDbTable.use(
      storage_v0.assets,
      func(doc : RxDbTable.AssetDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.AssetDocument) : Nat32 = doc.updatedAt,
    );
    contacts = RxDbTable.use(
      storage_v0.contacts,
      func(doc : RxDbTable.ContactDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.ContactDocument) : Nat32 = doc.updatedAt,
    );
    allowances = RxDbTable.use(
      storage_v0.allowances,
      func(doc : RxDbTable.AllowanceDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.AllowanceDocument) : Nat32 = doc.updatedAt,
    );
    services = RxDbTable.use(
      storage_v0.services,
      func(doc : RxDbTable.ServiceDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.ServiceDocument) : Nat32 = doc.updatedAt,
    );
    orders = RxDbTable.use(
      storage_v0.orders,
      func(doc : RxDbTable.OrderDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.OrderDocument) : Nat32 = doc.updatedAt,
    );
    paymentVerifications = RxDbTable.use(
      storage_v0.paymentVerifications,
      func(doc : RxDbTable.PaymentVerificationDocument) : Text = doc.orderId,
      Text.compare,
      func(doc : RxDbTable.PaymentVerificationDocument) : Nat32 = doc.updatedAt,
    );
    kycDetails = RxDbTable.use(
      storage_v0.kycDetails,
      func(doc : RxDbTable.KYCDocument) : Text = doc.userId,
      Text.compare,
      func(doc : RxDbTable.KYCDocument) : Nat32 = doc.updatedAt,
    );
    validators = RxDbTable.use(
      storage_v0.validators,
      func(doc : RxDbTable.ValidatorDocument) : Text = doc.id,
      Text.compare,
      func(doc : RxDbTable.ValidatorDocument) : Nat32 = doc.updatedAt,
    );
  };

  private func getDatabase(owner : Principal, notFoundStrategy : { #create; #returnNull }) : ?(
    RxDbTable.DbUse<AssetDocument, Text>, 
    RxDbTable.DbUse<ContactDocument, Text>, 
    RxDbTable.DbUse<AllowanceDocument, Text>, 
    RxDbTable.DbUse<ServiceDocument, Text>,
    RxDbTable.DbUse<OrderDocument, Text>,
    RxDbTable.DbUse<PaymentVerificationDocument, Text>,
    RxDbTable.DbUse<KYCDocument, Text>,
    RxDbTable.DbUse<ValidatorDocument, Text>
  )  {
    switch (AssocList.find(databasesCache, owner, Principal.equal)) {
      case (?db) ?db;
      case (null) {
        let (tInit, cInit, aInit, sInit, oInit, pInit, kInit, vInit) = switch (AssocList.find(storage_v0, owner, Principal.equal)) {
          case (?store) store;
          case (null) {
            switch (notFoundStrategy) {
              case (#returnNull) return null;
              case (#create) {
                let store = (
                  RxDbTable.empty<AssetDocument, Text>(),
                  RxDbTable.empty<ContactDocument, Text>(),
                  RxDbTable.empty<AllowanceDocument, Text>(),
                  RxDbTable.empty<ServiceDocument, Text>(),
                  RxDbTable.empty<OrderDocument, Text>(),
                  RxDbTable.empty<PaymentVerificationDocument, Text>(),
                  RxDbTable.empty<KYCDocument, Text>(),
                  RxDbTable.empty<ValidatorDocument, Text>()
                );
                let (upd, _) = AssocList.replace(storage_v0, owner, Principal.equal, ?store);
                storage_v0 := upd;
                store;
              };
            };
          };
        };
        let db = (
          RxDbTable.use<AssetDocument, Text>(tInit, func(x) = x.address, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<ContactDocument, Text>(cInit, func(x) = x.principal, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<AllowanceDocument, Text>(aInit, func(x) = x.id, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<ServiceDocument, Text>(sInit, func(x) = x.principal, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<OrderDocument, Text>(oInit, func(x) = x.id, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<PaymentVerificationDocument, Text>(pInit, func(x) = x.orderId, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<KYCDocument, Text>(kInit, func(x) = x.userId, Text.compare, func(x) = x.updatedAt),
          RxDbTable.use<ValidatorDocument, Text>(vInit, func(x) = x.id, Text.compare, func(x) = x.updatedAt)
        );
        let (upd, _) = AssocList.replace(databasesCache, owner, Principal.equal, ?db);
        databasesCache := upd;
        ?db;
      };
    };
  };

  public shared ({ caller }) func pushAssets(docs : [AssetDocument]) : async [AssetDocument] {
    let ?(tdb, _, _, _, _, _, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(tdb, docs);
  };

  public shared ({ caller }) func pushContacts(docs : [ContactDocument]) : async [ContactDocument] {
    let ?(_, cdb, _, _, _, _, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(cdb, docs);
  };

  public shared ({ caller }) func pushAllowances(docs : [AllowanceDocument]) : async [AllowanceDocument] {
    let ?(_, _, adb, _, _, _, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(adb, docs);
  };

  public shared ({ caller }) func pushServices(docs : [ServiceDocument]) : async [ServiceDocument] {
    let ?(_, _, _, sdb, _, _, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(sdb, docs);
  };

  public shared ({ caller }) func pushOrders(docs : [OrderDocument]) : async [OrderDocument] {
    let ?(_, _, _, _, odb, _, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(odb, docs);
  };

  public shared ({ caller }) func pushPaymentVerifications(docs : [PaymentVerificationDocument]) : async [PaymentVerificationDocument] {
    let ?(_, _, _, _, _, pdb, _, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(pdb, docs);
  };

  public shared ({ caller }) func pushKYCDetails(docs : [KYCDocument]) : async [KYCDocument] {
    let ?(_, _, _, _, _, _, kdb, _) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(kdb, docs);
  };

  public shared ({ caller }) func pushValidators(docs : [ValidatorDocument]) : async [ValidatorDocument] {
    let ?(_, _, _, _, _, _, _, vdb) = getDatabase(caller, #create) else Debug.trap("Can never happen");
    RxDbTable.pushUpdates(vdb, docs);
  };

  public shared query ({ caller }) func pullAssets(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [AssetDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(tdb, _, _, _, _, _, _, _)) RxDbTable.getLatest(tdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullContacts(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [ContactDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, cdb, _, _, _, _, _, _)) RxDbTable.getLatest(cdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullAllowances(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [AllowanceDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, adb, _, _, _, _, _)) RxDbTable.getLatest(adb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullServices(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [ServiceDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, sdb, _, _, _, _)) RxDbTable.getLatest(sdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullOrders(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) RxDbTable.getLatest(odb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullPaymentVerifications(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [PaymentVerificationDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, pdb, _, _)) RxDbTable.getLatest(pdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullKYCDetails(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [KYCDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) RxDbTable.getLatest(kdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query ({ caller }) func pullValidators(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [ValidatorDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) RxDbTable.getLatest(vdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query func dump() : async [(Principal, ([?AssetDocument], [?ContactDocument], [?AllowanceDocument], [?ServiceDocument], [?OrderDocument], [?PaymentVerificationDocument], [?KYCDocument], [?ValidatorDocument]))] {
    Iter.toArray<(Principal, ([?AssetDocument], [?ContactDocument], [?AllowanceDocument], [?ServiceDocument], [?OrderDocument], [?PaymentVerificationDocument], [?KYCDocument], [?ValidatorDocument]))>(
      Iter.map<(Principal, (RxDbTable.DbInit<AssetDocument, Text>, RxDbTable.DbInit<ContactDocument, Text>, RxDbTable.DbInit<AllowanceDocument, Text>, RxDbTable.DbInit<ServiceDocument, Text>, RxDbTable.DbInit<OrderDocument, Text>, RxDbTable.DbInit<PaymentVerificationDocument, Text>, RxDbTable.DbInit<KYCDocument, Text>, RxDbTable.DbInit<ValidatorDocument, Text>)), (Principal, ([?AssetDocument], [?ContactDocument], [?AllowanceDocument], [?ServiceDocument], [?OrderDocument], [?PaymentVerificationDocument], [?KYCDocument], [?ValidatorDocument]))>(
        List.toIter(storage_v0),
        func((p, (t, c, a, s, o, p, k, v))) = (p, (Vector.toArray<?AssetDocument>(t.db.vec), Vector.toArray<?ContactDocument>(c.db.vec), Vector.toArray<?AllowanceDocument>(a.db.vec), Vector.toArray<?ServiceDocument>(s.db.vec), Vector.toArray<?OrderDocument>(o.db.vec), Vector.toArray<?PaymentVerificationDocument>(p.db.vec), Vector.toArray<?KYCDocument>(k.db.vec), Vector.toArray<?ValidatorDocument>(v.db.vec))),
      )
    );
  };

  public shared query ({ caller }) func doesStorageExist() : async Bool {
    switch (AssocList.find(databasesCache, caller, Principal.equal)) {
      case (?_) true;
      case (null) false;
    };
  };

  // Helper methods for P2P operations
  public shared ({ caller }) func updateOrderStatus(orderId : Text, newStatus : Text) : async Result.Result<OrderDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        RxDbTable.updateOrderStatus(odb, orderId, newStatus, func(order : OrderDocument) : OrderDocument = {
          order with status = newStatus;
          updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  public shared ({ caller }) func getOrderById(orderId : Text) : async ?OrderDocument {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) RxDbTable.getById(odb, orderId);
      case (null) null;
    };
  };

  public shared ({ caller }) func getOrdersByStatus(status : Text) : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        RxDbTable.getByStatus(odb, status, func(order : OrderDocument) : Text = order.status);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func getActiveOrders() : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        RxDbTable.getActive(odb, func(order : OrderDocument) : Bool = order.deleted);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func getOrdersByDateRange(startTime : Int, endTime : Int) : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        RxDbTable.getByDateRange(odb, startTime, endTime, func(order : OrderDocument) : Int = order.createdAt);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func getOrdersByUser(userId : Text) : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        let orders = RxDbTable.getActive(odb, func(order : OrderDocument) : Bool = order.deleted);
        Array.filter<OrderDocument>(orders, func(order) = order.sellerId == userId);
      };
      case (null) [];
    };
  };

  // Helper methods for KYC operations
  public shared ({ caller }) func updateKYCStatus(
    userId : Text, 
    newStatus : Text, 
    verifier : Text, 
    remarks : ?Text
  ) : async Result.Result<KYCDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) {
        RxDbTable.updateKYCStatus(kdb, userId, newStatus, verifier, remarks, func(kyc : KYCDocument) : KYCDocument = {
          kyc with 
            status = newStatus;
            verificationDetails = ?{
              submittedAt = Time.now();
              verifiedAt = ?Time.now();
              verifiedBy = ?verifier;
              remarks = remarks;
            };
            updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  public shared ({ caller }) func getKYCByRiskLevel(riskLevel : Text) : async [KYCDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) {
        let kycs = RxDbTable.getActive(kdb, func(kyc : KYCDocument) : Bool = kyc.deleted);
        Array.filter<KYCDocument>(kycs, func(kyc) = kyc.riskLevel == riskLevel);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func getKYCByStatus(status : Text) : async [KYCDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) {
        RxDbTable.getByStatus(kdb, status, func(kyc : KYCDocument) : Text = kyc.status);
      };
      case (null) [];
    };
  };

  // Helper methods for Validator operations
  public shared ({ caller }) func updateValidatorStatus(
    validatorId : Text, 
    isActive : Bool
  ) : async Result.Result<ValidatorDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        RxDbTable.updateValidatorStatus(vdb, validatorId, isActive, func(validator : ValidatorDocument) : ValidatorDocument = {
          validator with 
            isActive = isActive;
            updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  public shared ({ caller }) func getActiveValidators() : async [ValidatorDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        RxDbTable.getActive(vdb, func(validator : ValidatorDocument) : Bool = validator.deleted);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func getValidatorsByRating(minRating : Float) : async [ValidatorDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        let validators = RxDbTable.getActive(vdb, func(validator : ValidatorDocument) : Bool = validator.deleted);
        Array.filter<ValidatorDocument>(validators, func(validator) = validator.rating >= minRating);
      };
      case (null) [];
    };
  };

  public shared ({ caller }) func updateValidatorRating(validatorId : Text, newRating : Float) : async Result.Result<ValidatorDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        RxDbTable.updateValidatorStatus(vdb, validatorId, true, func(validator : ValidatorDocument) : ValidatorDocument = {
          validator with 
            rating = newRating;
            updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  public shared ({ caller }) func updateValidatorResponseTime(validatorId : Text, responseTime : Text) : async Result.Result<ValidatorDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        RxDbTable.updateValidatorStatus(vdb, validatorId, true, func(validator : ValidatorDocument) : ValidatorDocument = {
          validator with 
            responseTime = responseTime;
            updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  public shared ({ caller }) func incrementValidatorOrders(validatorId : Text) : async Result.Result<ValidatorDocument, Text> {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        RxDbTable.updateValidatorStatus(vdb, validatorId, true, func(validator : ValidatorDocument) : ValidatorDocument = {
          validator with 
            totalOrders = validator.totalOrders + 1;
            updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
        });
      };
      case (null) #err("Database not found");
    };
  };

  // Additional query methods for P2P operations
  public shared query func getLatestOrders(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [OrderDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) RxDbTable.getLatest(odb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  public shared query func getLatestPaymentVerifications(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [PaymentVerificationDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, pdb, _, _)) RxDbTable.getLatest(pdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  // Additional query methods for KYC operations
  public shared query func getLatestKYCDetails(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [KYCDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) RxDbTable.getLatest(kdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  // Additional query methods for Validator operations
  public shared query func getLatestValidators(updatedAt : Nat32, lastId : ?Text, limit : Nat) : async [ValidatorDocument] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) RxDbTable.getLatest(vdb, updatedAt, lastId, limit);
      case (null) [];
    };
  };

  // Batch operations for P2P
  public shared ({ caller }) func batchUpdateOrderStatus(orderIds : [Text], newStatus : Text) : async [Result.Result<OrderDocument, Text>] {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        Array.map<Text, Result.Result<OrderDocument, Text>>(
          orderIds,
          func(orderId) = DB.updateOrderStatus(
            odb,
            orderId,
            newStatus,
            func(order : OrderDocument) : OrderDocument = {
              order with 
                status = newStatus;
                updatedAt = Nat32.fromNat(Int.abs(Time.now() / 1_000_000_000));
            }
          )
        );
      };
      case (null) Array.map<Text, Result.Result<OrderDocument, Text>>(orderIds, func(_) = #err("Database not found"));
    };
  };

  // Statistics for P2P operations
  public shared query ({ caller }) func getOrderStatistics() : async {
    totalOrders : Nat;
    activeOrders : Nat;
    completedOrders : Nat;
    disputedOrders : Nat;
  } {
    let result = switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, odb, _, _, _)) {
        let orders = DB.getActive(odb, func(order : OrderDocument) : Bool { order.deleted });
        {
          totalOrders = orders.size();
          activeOrders = Array.filter<OrderDocument>(orders, func(o) { o.status == "open" or o.status == "payment_pending" }).size();
          completedOrders = Array.filter<OrderDocument>(orders, func(o) { o.status == "completed" }).size();
          disputedOrders = Array.filter<OrderDocument>(orders, func(o) { o.status == "disputed" }).size();
        }
      };
      case (null) {
        {
          totalOrders = 0;
          activeOrders = 0;
          completedOrders = 0;
          disputedOrders = 0;
        }
      };
    };
    result
  };

  // KYC Statistics
  public shared query ({ caller }) func getKYCStatistics() : async {
    totalUsers : Nat;
    pendingVerifications : Nat;
    approvedUsers : Nat;
    rejectedUsers : Nat;
    highRiskUsers : Nat;
  } {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, kdb, _)) {
        let kycs = DB.getActive(kdb, func(kyc : KYCDocument) : Bool { kyc.deleted });
        {
          totalUsers = kycs.size();
          pendingVerifications = Array.filter<KYCDocument>(kycs, func(k) { k.status == "pending" }).size();
          approvedUsers = Array.filter<KYCDocument>(kycs, func(k) { k.status == "approved" }).size();
          rejectedUsers = Array.filter<KYCDocument>(kycs, func(k) { k.status == "rejected" }).size();
          highRiskUsers = Array.filter<KYCDocument>(kycs, func(k) { k.riskLevel == "high" }).size();
        }
      };
      case (null) {
        {
          totalUsers = 0;
          pendingVerifications = 0;
          approvedUsers = 0;
          rejectedUsers = 0;
          highRiskUsers = 0;
        }
      };
    };
  };

  // Validator Statistics
  public shared query ({ caller }) func getValidatorStatistics() : async {
    totalValidators : Nat;
    activeValidators : Nat;
    averageRating : Float;
    totalOrdersProcessed : Nat;
  } {
    switch (getDatabase(caller, #returnNull)) {
      case (?(_, _, _, _, _, _, _, vdb)) {
        let validators = DB.getActive(vdb, func(validator : ValidatorDocument) : Bool { validator.deleted });
        let activeVals = Array.filter<ValidatorDocument>(validators, func(v) { v.isActive });
        let totalRating = Array.foldLeft<ValidatorDocument, Float>(
          validators,
          0.0,
          func(acc, v) { acc + v.rating }
        );
        let totalOrders = Array.foldLeft<ValidatorDocument, Nat>(
          validators,
          0,
          func(acc, v) { acc + v.totalOrders }
        );
        {
          totalValidators = validators.size();
          activeValidators = activeVals.size();
          averageRating = if (validators.size() > 0) { totalRating / Float.fromInt(validators.size()) } else { 0.0 };
          totalOrdersProcessed = totalOrders;
        }
      };
      case (null) {
        {
          totalValidators = 0;
          activeValidators = 0;
          averageRating = 0.0;
          totalOrdersProcessed = 0;
        }
      };
    };
  };
  };
};