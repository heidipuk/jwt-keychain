import Vapor
import Auth
import Foundation
import HTTP
import Turnstile
import TurnstileCrypto
import TurnstileWeb
import VaporForms
import VaporJWT
import Flash

/// Controller for reset password requests
open class FrontendResetPasswordController: FrontendResetPasswordControllerType {

    public let configuration: ConfigurationType

    private let drop: Droplet

    required public init(drop: Droplet, configuration: ConfigurationType) {
        self.configuration = configuration
        self.drop = drop
    }

    open func resetPasswordForm(request: Request, token: String) throws -> View {

        // Validate token
        if try !self.configuration.validateToken(token: token) {
            throw Abort.notFound
        }

        let jwt = try JWT(token: token)

        guard
            let userId = jwt.payload["user"]?.object?["id"]?.int,
            let _ = try User.query().filter("id", userId).first() else {
                throw Abort.notFound
        }

        return try drop.view.make("ResetPassword/form", ["token": token])
    }

    open func resetPasswordChange(request: Request) throws -> Response {

        do {
            // Validate request
            let requestData = try ResetPasswordRequest(validating: request.data)

            // Validate token
            if try !self.configuration.validateToken(token: requestData.token) {
                return Response(redirect: "/api/v1/users/reset-password/form")
                    .flash(.error, "Token is invalid")
            }

            let jwt = try JWT(token: requestData.token)

            guard
                let userId = jwt.payload["user"]?.object?["id"]?.int,
                let userPasswordHash = jwt.payload["user"]?.object?["password"]?.string,
                var user = try User.query().filter("id", userId).first() else {
                    return Response(redirect: "/api/v1/users/reset-password/form")
                        .flash(.error, "Token is invalid")
            }

            if user.email != requestData.email {
                return Response(redirect: "/api/v1/users/reset-password/form")
                    .flash(.error, "Email did not match")
            }

            if user.password != userPasswordHash {
                return Response(redirect: "/api/v1/users/reset-password/form")
                    .flash(.error, "Password already changed. Cannot use the same token again.")
            }

            if requestData.password != requestData.passwordConfirmation {
                return Response(redirect: "/api/v1/users/reset-password/form")
                    .flash(.error, "Password and password confirmation don't match")
            }

            user.password = BCrypt.hash(password: requestData.password)
            try user.save()

            return Response(redirect: "/api/v1/users/reset-password/form")
                .flash(.success, "Password changed. You can close this page now.")


        } catch FormError.validationFailed(let fieldset) {

            let response = Response(redirect: "/api/v1/users/reset-password/form").flash(.error, "Data is invalid")
            response.storage["_fieldset"] = try fieldset.makeNode()
            
            return response
            
        } catch {
            return Response(redirect: "/api/v1/users/reset-password/form")
                .flash(.error, "Something went wrong")
        }
        
    }
}