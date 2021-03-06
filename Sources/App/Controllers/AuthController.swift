//
//  File.swift
//  
//
//  Created by laijihua on 2020/4/17.
//

import Fluent
import Vapor

struct AuthController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        routes.group("auth") { auth in
            auth.post("register", use: register)
            auth.post("login", use: login)

//            auth.group("email", "verification") { emailVerificationRoutes in
//                emailVerificationRoutes.post("", use: sendEmailVerification)
//                emailVerificationRoutes.get("", use: verifyEmail)
//            }
//
//            auth.group("reset", "password") { resetPasswordRoutes in
//                resetPasswordRoutes.post("", use: resetPassword)
//                resetPasswordRoutes.get("verify", use: verifyResetPasswordToken)
//            }
//
//            auth.post("recover", use: recoverAccount)
            auth.post("accessToken", use: refreshAccessToken)

        }

    }
}

extension AuthController {
    private func register(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        try InputRegister.validate(req)
        let inputRegister = try req.content.decode(InputRegister.self)

        return req.repositoryUserAuths
            .find(authType: .email, identifier: inputRegister.email)
            .guard({ $0 == nil }, else: ApiError(code: .userExist))
            .transform(to: User(name: inputRegister.name, email: inputRegister.email))
            .flatMap { user in
                return req.repositoryUsers.create(user).map { user }
            }
            .and(req.password.async.hash(inputRegister.password))
            .flatMapThrowing { user, pwd in
                return try UserAuth(userId: user.requireID(), authType: .email, identifier: inputRegister.email, credential: pwd)
            }
            .flatMap { userAuth in
                return userAuth.create(on: req.db).map { userAuth }
            }.transform(to: .created)

            //TODO: send email need

    }

    private func login(_ req: Request) throws -> EventLoopFuture<OutputJson<OutputLogin>> {
        try InputLogin.validate(req)
        let inputLogin = try req.content.decode(InputLogin.self)
        return req.repositoryUserAuths
            .find(authType: .email, identifier: inputLogin.email)
            .unwrap(or: ApiError(code: .emailNotExist))
            .flatMap { userAuth in
                return req.password
                    .async
                    .verify(inputLogin.password, created: userAuth.credential)
                    .guard({$0 == true}, else: ApiError(code: .invalidEmailOrPassword))
                    .transform(to: userAuth)
        }.flatMap { userAuth in
            let tokenFuture = req.authService.authenticationFor(userId: userAuth.$user.id)
            let userFuture = req.repositoryUsers
                .find(id: userAuth.$user.id)
                .unwrap(or: ApiError(code: .userNotExist))
                .map { OutputUser(from: $0)}
            return tokenFuture
                .and(userFuture)
                .map({ token, user in OutputJson(success: OutputLogin(user: user, token: token))})
        }
    }

    private func refreshAccessToken(_ req: Request) throws -> EventLoopFuture<OutputJson<OutputAuthentication>> {
        let inputAccessToken = try req.content.decode(InputAccessToken.self)
        return req.authService
            .authentication(refreshToken: inputAccessToken.refreshToken)
            .map{ OutputJson(success: $0) }
    }
//    private func sendEmailVerification(_ req: Request) throws -> EventLoopFuture<HTTPStatus>{}
//    private func recoverAccount(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {}
//    private func verifyEmail(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {}
//    private func resetPassword(_ req: Request) throws -> EventLoopFuture<HTTPStatus>{}
//    private func verifyResetPasswordToken(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {}
}
