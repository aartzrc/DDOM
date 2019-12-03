class FieldAccessTest  {
    static function main() {
        // Create a generic 'customer' and assign some values
        var customer = Item.create("customer");
        customer.firstName = "Jon";
        customer.lastName = "Doe";

        // 'type' is hidden by the field accessor (good!)
        trace(customer.type);
        
        // but we can cast and get at the internal type, neat!
        var gs:GenericStore = cast customer;
        trace(gs.type);

        // we do not have code-completion or type safety yet, so lets add a typedef to make this 'customer' look right to the compiler
        // cast to a typedef for code-completion/type safety to kick in
        var castedCustomer:CustomerDef = cast customer;
        // dang, we loose the abstract field read/write!
        trace(castedCustomer.firstName);

        var castedCustomer2 = cast(customer, Customer);
        trace(castedCustomer2.firstName);
    }
}

@:access(GenericStore)
abstract Customer(GenericStore) {
    public var firstName(get,set):String;
    public var lastName(get,set):String;

    function get_firstName() {
        return Reflect.field(this.fields, "firstName");
    }
    function set_firstName(val:String) {
        Reflect.setField(this.fields, "firstName", val);
        return val;
    }

    function get_lastName() {
        return Reflect.field(this.fields, "lastName");
    }
    function set_lastName(val:String) {
        Reflect.setField(this.fields, "lastName", val);
        return val;
    }
}

class GenericStore {
    public var type:String;
    var fields = {};

    function new(type:String) {
        this.type = type;
    }
}

@:access(GenericStore)
abstract Item(GenericStore) from (GenericStore) {
    @:op(a.b)
    public function fieldWrite<T>(name:String, value:T) Reflect.setField(this.fields, name, value);
    @:op(a.b)
    public function fieldRead<T>(name:String):T return Reflect.field(this.fields, name);

    public static function create(type:String):Item return new GenericStore(type);
}

typedef CustomerDef = { 
    firstName:String, 
    lastName:String 
};