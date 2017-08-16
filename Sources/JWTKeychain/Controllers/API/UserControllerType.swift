import Vapor
import HTTP

/// Defines basic authorization functionality.
public protocol UserControllerType {
    func register(request: Request) throws -> ResponseRepresentable
    func logIn(request: Request) throws -> ResponseRepresentable
    func logOut(request: Request) throws -> ResponseRepresentable
    func regenerate(request: Request) throws -> ResponseRepresentable
    func me(request: Request) throws -> ResponseRepresentable
    func resetPasswordEmail(request: Request) throws -> ResponseRepresentable
    func update(request: Request) throws -> ResponseRepresentable
}

extension UserControllerType {
    
    // Provide a default implementation for scenarios without refresh tokens.
    func regenerate(_: Request) throws -> ResponseRepresentable {
        fatalError("Not implemented.")
    }
}
