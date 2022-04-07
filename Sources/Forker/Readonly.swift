import Foundation

@propertyWrapper
public struct Readonly<A> {
    
    public var get: () -> A

    public var value: A { get { get() } }

    public var wrappedValue: A { value }

    public init(wrappedValue: A) {
        self = Self { wrappedValue }
    }
    
    public init(_ readonly: Readonly) {
        self = readonly
    }
    
    public init(get: @escaping () -> A) {
        self.get = get
    }
    
}
