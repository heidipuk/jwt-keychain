import Foundation
import Vapor

/// Controller for user API requests. Forwards all calls to its delegate.
final internal class APIUserController {
    private let delegate: APIUserControllerDelegateType
    private let passwordResetMailer: PasswordResetMailerType
    private let tokenGenerators: TokenGenerators

    internal init(
        delegate: APIUserControllerDelegateType,
        passwordResetMailer: PasswordResetMailerType,
        tokenGenerators: TokenGenerators
    ) {
        self.delegate = delegate
        self.passwordResetMailer = passwordResetMailer
        self.tokenGenerators = tokenGenerators
    }

    /// Registers a user and created an instance in the database.
    ///
    /// - Parameter request: current request.
    /// - Returns: JSON response with User data.
    /// - Throws: Any error from the delegate call.
    internal func register(request: Request) throws -> ResponseRepresentable {
        return try delegate.register(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }

    /// Logs the user in to the system, giving the token back.
    ///
    /// - Parameter request: current request.
    /// - Returns: JSON response with User data.
    /// - Throws: Any error from the delegate call.
    internal func logIn(request: Request) throws -> ResponseRepresentable {
        return try delegate.logIn(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }

    /// Logs the user out of the system.
    ///
    /// - Parameter request: current request.
    /// - Returns: JSON success response.
    /// - Throws: Any error from the delegate call.
    internal func logOut(request: Request) throws -> ResponseRepresentable {
        return try delegate.logOut(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }

    /// Generates a new token for the user.
    ///
    /// - Parameter request: current request.
    /// - Returns: JSON with token.
    /// - Throws: Any error from the delegate call.
    internal func regenerate(request: Request) throws -> ResponseRepresentable {
        return try delegate.regenerate(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }

    /// Returns the authenticated user data.
    ///
    /// - Parameter request: current request.
    /// - Returns: JSON response with User data.
    /// - Throws: Any error from the delegate call.
    internal func me(request: Request) throws -> ResponseRepresentable {
        return try delegate.me(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }

    /// Requests a reset of password for the given email.
    ///
    /// - Parameter request: current request.
    /// - Returns: success or failure message
    /// - Throws: Any error from the delegate call.
    internal func resetPasswordEmail(
        request: Request
    ) throws -> ResponseRepresentable {
        return try delegate.resetPasswordEmail(
            request: request,
            tokenGenerators: tokenGenerators,
            passwordResetMailer: passwordResetMailer
        )
    }

    /// Update a user's info (including password)
    ///
    /// - Parameter request: current request.
    /// - Returns: success or failure message
    /// - Throws: Any error from the delegate call.
    func update(request: Request) throws -> ResponseRepresentable {
        return try delegate.update(
            request: request,
            tokenGenerators: tokenGenerators
        )
    }
}
