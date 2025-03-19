import BTree "mo:stableheapbtreemap/BTree";
import IDX "index";
import PK "primarykey";
import RXMDB "lib";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Vector "mo:vector";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Iter "mo:base/Iter";

module RxDbTable {
  /**
    **Type** that serves as a blueprint for creating and initializing a new database table in the `rxmodb` system.

    **Return (implicit):**

    * An object of type `DatabaseInit<T, PK>`. This object encapsulates the following configuration elements:
      - `db`: An object of type `RXMDB.RXMDB<T>` representing the core database table structure and configuration.
      - `pk`: An object of type `PK.Init<PK>` defining the primary key mechanism for the table.
      - `updatedAt`: An object of type `IDX.Init<Nat64>` defining an index to track update timestamps for documents, without directly modifying their fields.
  */
  type DbInit<T, PK> = {
    db : RXMDB.RXMDB<T>;
    pk : PK.Init<PK>;
    updatedAt : IDX.Init<Nat64>;
  };
  /**
    **Type** that provides the functionalities to interact with a database table in the `rxmodb` system after it has been initialized.

    **Return (implicit):**

    * An object of type `DatabaseUse<T, PK>`. This object provides the following functionalities:
      - `db`: An object of type `RXMDB.Use<T>` for interacting with the actual table data (inserting, updating, deleting, etc.).
      - `pk`: An object of type `PK.Use<PK, T>` for interacting with the primary key mechanism (searching by primary key, etc.).
      - `updatedAt`: An object of type `IDX.Use<Nat64, T>` for interacting with the update timestamp index (searching based on update timestamps, etc.).
  */
  type DbUse<T, PK> = {
    db : RXMDB.Use<T>;
    pk : PK.Use<PK, T>;
    updatedAt : IDX.Use<Nat64, T>;
  };

  /**
    Initializes a new database table with basic configuration in the `rxmodb` system.

    **Returns:**

    * An object of type `DatabaseInit<T, PK>` representing the initial configuration for the table:
      - `db`: An object of type `RXMDB.Init<T>` for the core database table.
      - `pk`: An object of type `PK.Init<PK>` for primary key management, initialized with a key size of 32 bits.
      - `updatedAt`: An object of type `IDX.Init<Nat64>` for the update timestamp index, initialized with a key size of 32 bits.
  */
  public func empty<T, PK>() : DbInit<T, PK> = {
    db = RXMDB.init<T>();
    pk = PK.init<PK>(?32);
    updatedAt = IDX.init<Nat64>(?32);
  };

  /**
    Initializes and configures the necessary mechanisms (observables to updatedAt and primary key) to interact with a database table within the `rxmodb` system.

    **Parameters:**

    * `init`: An object of type `DatabaseInit<T, PK>` representing the initial configuration for the table (data structure, primary key type, update timestamp index).
    * `pkGet`: A function that extracts the unique identifier (primary key) from a data item of type `T`.
    * `pkCompare`: A function that compares two primary keys and returns an indication of their relative order (less than, equal to, or greater than).
    * `updatedAtGet`: A function that retrieves the last updated timestamp (as a `Nat32` value) from a data item of type `T`.

    **Returns:**

    * A handle of type `DatabaseUse<T, PK>`. This object provides functionalities to interact with the actual table data (`db`), primary keys (`pk`), and the update timestamp index (`updatedAt`).
  */
  public func use<T, PK>(
    init : DbInit<T, PK>,
    pkGet : T -> PK,
    pkCompare : (PK, PK) -> { #less; #equal; #greater },
    updatedAtGet : T -> Nat32,
  ) : DbUse<T, PK> {
    let obs = RXMDB.init_obs<T>();

    let pk_config : PK.Config<PK, T> = {
      db = init.db;
      obs;
      store = init.pk;
      compare = pkCompare;
      key = pkGet;
      regenerate = #no;
    };
    PK.Subscribe<PK, T>(pk_config);

    let updatedAt_config : IDX.Config<Nat64, T> = {
      db = init.db;
      obs;
      store = init.updatedAt;
      compare = Nat64.compare;
      key = func(idx : Nat, d : T) = ?((Nat64.fromNat(Nat32.toNat(updatedAtGet(d))) << 32) | Nat64.fromNat(idx));
      regenerate = #no;
      keep = #all;
    };
    IDX.Subscribe(updatedAt_config);

    return {
      db = RXMDB.Use<T>(init.db, obs);
      pk = PK.Use(pk_config);
      updatedAt = IDX.Use(updatedAt_config);
    };
  };

  /**
    This function iterates through each document in the `docs` array and inserts it into the database table using the `insert` function of the `db` object within the `DatabaseUse` handle.

    **Parameters:**

    * `use`: A handle of type `DatabaseUse<T, PK>` that provides access to the database table functionalities.
    * `docs`: An array of type `[T]` containing the documents to be pushed to the database.

    **Returns:**

    An empty array `[]`.
  */
  public func pushUpdates<T, PK>(use : DbUse<T, PK>, docs : [T]) : [T] {
    for (doc in docs.vals()) {
      use.db.insert(doc);
    };

    [];
  };

  /**
    Retrieves a list of the latest documents from a database table, considering both update timestamps and primary keys.

    **Parameters:**

    * `use`: A handle of type `DbUse<T, PK>` that provides access to the database table functionalities.
    * `updatedAt`: A `Nat32` value representing the minimum update timestamp for the desired documents (inclusive).
    * `lastId`: An optional `PK` value representing the primary key of the last document retrieved in a previous call (for pagination).
    * `limit`: A `Nat` value specifying the maximum number of documents to retrieve.

    **Returns:**

    * An array of type `[T]` containing the retrieved documents. The documents are sorted in descending order of update timestamp, with documents having the same timestamp further sorted by primary key (descending).

    **Notes:**

    * If `lastId` is provided, the function starts searching from the document with the corresponding primary key and the specified update timestamp.
    * If `lastId` is not provided, the function retrieves documents only based on the `updatedAt` (all documents after that timestamp).
  */
  public func getLatest<T, PK>(use : DbUse<T, PK>, updatedAt : Nat32, lastId : ?PK, limit : Nat) : [T] {
    let start : Nat64 = switch (lastId) {
      case (?id) {
        let ?idx = use.pk.getIdx(id) else Debug.trap("ID not found");
        (Nat64.fromNat(Nat32.toNat(updatedAt)) << 32) | Nat64.fromNat(idx);
      };
      case (null) Nat64.fromNat(Nat32.toNat(updatedAt)) << 32;
    };
    use.updatedAt.find(start, ^0, #bwd, limit);
  };

  /**

  This function takes a source table blueprint (`DbInit<T1, PK1>`) and provides functions to convert both the data and primary keys to a new format for a destination table. It returns a new table blueprint (`DbInit<T2, PK2>`) representing the migrated data and configuration.

  **Parameters:**

  * `src`: An object of type `DbInit<T1, PK1>` representing the source table blueprint (data structure, primary key mechanism, update timestamp index).
  * `cast`: A function that transforms data items of type `T1` from the source table to the desired type `T2` for the destination table.
  * `castPk`: A function that converts primary keys of type `PK1` from the source table to the appropriate type `PK2` for the destination table.

  **Return:**

  * An object of type `DbInit<T2, PK2>` representing the migrated table blueprint:
    - `db`: An object encapsulating the migrated data structure for the destination table.
    - `pk`: An object defining the primary key mechanism for the destination table, using the converted primary keys.
    - `updatedAt`: The update timestamp index from the source table is directly reused for the destination table (no conversion needed).
  */
  public func migrate<T1, PK1, T2, PK2>(src : DbInit<T1, PK1>, cast : T1 -> T2, castPk : PK1 -> PK2) : DbInit<T2, PK2> {
    func castData(data : BTree.Data<PK1, Nat>) : BTree.Data<PK2, Nat> = {
      var count = data.count;
      kvs = Array.tabulateVar<?(PK2, Nat)>(
        data.kvs.size(),
        func(n) = switch (data.kvs[n]) { case (null) null; case (?k) ?(castPk(k.0), k.1) },
      );
    };
    func castIndexNodeRecv(node : BTree.Node<PK1, Nat>) : BTree.Node<PK2, Nat> = switch (node) {
      case (#leaf x) #leaf({ data = castData(x.data) });
      case (#internal x) #internal({
        children = Array.tabulateVar<?BTree.Node<PK2, Nat>>(
          x.children.size(),
          func(n) = switch (x.children[n]) {
            case (null) null;
            case (?k) ?castIndexNodeRecv(k);
          },
        );
        data = castData(x.data);
      });
    };
    {
      db = {
        var reuse_queue = src.db.reuse_queue;
        vec = Vector.map<?T1, ?T2>(
          src.db.vec,
          func(x) = switch (x) {
            case (?item) ?cast(item);
            case (null) null;
          },
        );
      };
      pk = {
        order = src.pk.order;
        var size = src.pk.size;
        var root = castIndexNodeRecv(src.pk.root);
      };
      updatedAt = src.updatedAt;
    };
  };

  // Helper functions for P2P operations
  public func updateOrderStatus<T>(
    use : DbUse<T, Text>,
    orderId : Text,
    newStatus : Text,
    updateOrder : T -> T,
  ) : Result.Result<T, Text> {
    switch (use.pk.get(orderId)) {
      case (null) #err("Order not found");
      case (?order) {
        let updatedOrder = updateOrder(order);
        use.db.insert(updatedOrder);
        #ok(updatedOrder);
      };
    };
  };

  // Helper functions for KYC operations
  public func updateKYCStatus<T>(
    use : DbUse<T, Text>,
    userId : Text,
    newStatus : Text,
    verifier : Text,
    remarks : ?Text,
    updateKYC : T -> T,
  ) : Result.Result<T, Text> {
    switch (use.pk.get(userId)) {
      case (null) #err("KYC record not found");
      case (?kyc) {
        let updatedKYC = updateKYC(kyc);
        use.db.insert(updatedKYC);
        #ok(updatedKYC);
      };
    };
  };

  // Helper functions for Validator operations
  public func updateValidatorStatus<T>(
    use : DbUse<T, Text>,
    validatorId : Text,
    isActive : Bool,
    updateValidator : T -> T,
  ) : Result.Result<T, Text> {
    switch (use.pk.get(validatorId)) {
      case (null) #err("Validator not found");
      case (?validator) {
        let updatedValidator = updateValidator(validator);
        use.db.insert(updatedValidator);
        #ok(updatedValidator);
      };
    };
  };

  // Helper function to get a single document by ID
  public func getById<T>(use : DbUse<T, Text>, id : Text) : ?T {
    use.pk.get(id);
  };

  // Helper function to get multiple documents by IDs
  public func getByIds<T>(use : DbUse<T, Text>, ids : [Text]) : [T] {
    Array.mapFilter<Text, T>(ids, func(id) = use.pk.get(id));
  };

  // Helper function to delete a document
  public func deleteDocument<T>(use : DbUse<T, Text>, id : Text) : Result.Result<(), Text> {
    switch (use.pk.get(id)) {
      case (null) #err("Document not found");
      case (?doc) {
        use.pk.delete(id);
        #ok();
      };
    };
  };

  // Helper function to get documents by status
  public func getByStatus<T>(
    use : DbUse<T, Text>,
    status : Text,
    getStatus : T -> Text,
  ) : [T] {
    let docs = Array.mapFilter<(Text, Nat), T>(
      use.pk.findIdx("", "~", #fwd, 1000),
      func((_, idx)) = use.db.getIdx(idx),
    );
    Array.filter<T>(docs, func(doc) = getStatus(doc) == status);
  };

  // Helper function to get documents by date range
  public func getByDateRange<T>(
    use : DbUse<T, Text>,
    startTime : Int,
    endTime : Int,
    getTimestamp : T -> Int,
  ) : [T] {
    let docs = Array.mapFilter<(Text, Nat), T>(
      use.pk.findIdx("", "~", #fwd, 1000),
      func((_, idx)) = use.db.getIdx(idx),
    );
    Array.filter<T>(docs, func(doc) {
      let timestamp = getTimestamp(doc);
      timestamp >= startTime and timestamp <= endTime;
    });
  };

  // Helper function to get active documents
  public func getActive<T>(
    use : DbUse<T, Text>,
    isDeleted : T -> Bool,
  ) : [T] {
    let docs = Array.mapFilter<(Text, Nat), T>(
      use.pk.findIdx("", "~", #fwd, 1000),
      func((_, idx)) = use.db.getIdx(idx),
    );
    Array.filter<T>(docs, func(doc) = not isDeleted(doc));
  };

};

// P2P Types
type PaymentMethodDetails = {
  accountNumber : ?Text;
  accountName : ?Text;
  bankName : ?Text;
  walletAddress : ?Text;
};

type PaymentMethod = {
  id : Text;
  name : Text;
  methodType : Text; // "bank" | "gcash" | "maya" | "coins.ph"
  details : PaymentMethodDetails;
};

type OrderDocument = {
  id : Text;
  sellerId : Text;
  amount : Float;
  price : Float;
  status : Text;
  createdAt : Int; // Timestamp
  expiresAt : Int; // Timestamp
  paymentMethod : PaymentMethod;
  escrowId : ?Text;
  updatedAt : Nat32;
  deleted : Bool;
};

type PaymentVerificationDocument = {
  orderId : Text;
  status : Text; // "pending" | "verified" | "rejected"
  proof : ?Text;
  verifiedAt : ?Int; // Timestamp
  verifiedBy : ?Text;
  updatedAt : Nat32;
  deleted : Bool;
};

// KYC Types
type BankDetails = {
  gcash : ?Text;
  paymaya : ?Text;
  bpi : ?{
    accountNumber : Text;
    accountName : Text;
  };
};

type KYCDocument = {
  userId : Text;
  status : Text; // "pending" | "approved" | "rejected"
  personalInfo : {
    firstName : Text;
    lastName : Text;
    dateOfBirth : Text;
    nationality : Text;
    phoneNumber : Text;
    email : Text;
  };
  address : {
    street : Text;
    city : Text;
    state : Text;
    country : Text;
    postalCode : Text;
  };
  documents : [{
    type_ : Text;
    number : Text;
    expiryDate : Text;
    fileUrl : Text;
    verificationStatus : Text;
  }];
  verificationDetails : ?{
    submittedAt : Int;
    verifiedAt : ?Int;
    verifiedBy : ?Text;
    remarks : ?Text;
  };
  riskLevel : Text; // "low" | "medium" | "high"
  bankDetails : ?BankDetails;
  updatedAt : Nat32;
  deleted : Bool;
};

// Validator Types
type ValidatorDocument = {
  id : Text;
  name : Text;
  isActive : Bool;
  rating : Float;
  responseTime : Text;
  totalOrders : Nat;
  avatarUrl : ?Text;
  updatedAt : Nat32;
  deleted : Bool;
};

// Existing document types...
type AssetDocument_v0 = {
  // ... existing code ...
};
