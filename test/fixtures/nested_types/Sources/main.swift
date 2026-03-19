struct Outer {
    var outerProp: Int

    struct Inner {
        var innerProp: String

        struct DeepNested {
            var deepProp: Bool
        }
    }

    enum Status {
        case active
        case inactive

        struct Info {
            var detail: String
        }
    }

    class Helper {
        func help() -> String {
            return "helping"
        }
    }
}

class Container<T> {
    var items: [T] = []

    class Node<U> {
        var value: U?
    }
}
