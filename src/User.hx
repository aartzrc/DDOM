import ddom.DataNode;
using ddom.DDOM;

@:access(ddom.DataNode)
abstract User(DataNode) from DataNode {
    public static inline var type = "user";

    public static function create(id:Int, name:String) {
        var userDDOM = DDOM.create(type);
        userDDOM.id = Std.string(id);
        var user:User = userDDOM.nodesOfType(type)[0];
        user.name = name;
        user.createTimestamp = Date.now().getTime();
        return userDDOM;
    }

    public var id(get,never):Int;

    function get_id() {
        return Std.parseInt(this.getField("id"));
    }

    public var name(get,set):String;

    function get_name() {
        return this.getField("name");
    }

    function set_name(name:String) {
        this.setField("name", name);
        return name;
    }

    public var createTimestamp(get,set):Float;

    function get_createTimestamp() {
        return Std.parseFloat(this.getField("createTimestamp"));
    }

    function set_createTimestamp(time:Float) {
        this.setField("createTimestamp", Std.string(time));
        return time;
    }

    public function onChange(field:String, callback:(String)->Void):()->Void {
        function handleEvent(e) {
            switch(e) {
                case FieldSet(node, name, val):
                    if(name == field) callback(val);
                case _:
                    // Not handled here
            }
        }
        this.on(handleEvent);
        return this.off.bind(handleEvent);
    }

    public static function users(ddom:DDOM):Array<User> {
        return DDOM.nodesOfType(ddom, type);
    }
}

