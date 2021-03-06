//
//  File.swift
//  
//
//  Created by laijihua on 2020/4/16.
//

import Fluent
import Vapor

final class UserAuth: Model, Content {

    static let schema = "user_auths"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")  // 1 - n
    var user: User

    @Enum(key: "auth_type") // 认证类型
    var authType: AuthType

    @Field(key: "identifier")
    var identifier: String // 标志 (手机号，邮箱，用户名或第三方应用的唯一标识)

    @Field(key: "credential")
    var credential: String // 密码凭证(站内的保存密码， 站外的不保存或保存 token)

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, userId: UUID, authType: AuthType = .email, identifier: String, credential: String) {
        self.id = id
        self.$user.id = userId
        self.authType = authType
        self.identifier = identifier
        self.credential = credential
    }
}

extension UserAuth {
    enum AuthType: String, Codable {
        static let schema = "AUTHTYPE"
        case email, wxapp
    }
}

