//
//  RequstManager.swift
//  RxSwiftPractise
//
//  Created by lieon on 2017/11/12.
//  Copyright © 2017年 Personal. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import ObjectMapper
import Alamofire

protocol EndpointAccess {
    var baseURL: String { get }
    var path: String { get }
    var endpoint: String { get }
    var method: HTTPMethod { get}
    
    func URL() -> String
}

extension EndpointAccess {
    func URL() -> String {
        return baseURL + path + endpoint
    }
    
    var method: HTTPMethod {
        return .post
    }
    
}

class AppError: Error {
    
}

class Model: Mappable {
    public init () {
        
    }
    
    required init?(map: Map) {
        
    }
    
    open func mapping(map: Map) {
        
    }
}

extension Model: CustomDebugStringConvertible {
    var debugDescription: String {
        var str = "\n"
        let properties = Mirror(reflecting: self).children
        for child in properties {
            if let name = child.label {
                str += name + ": \(child.value)\n"
            }
        }
        return str
    }
    
}

class Header: Model {
    var token: String {
        get { return "sever-token" }
        set { }
    }
    var contentType: String = "application/json"
    
    override func mapping(map: Map) {
        token <- map["token"]
        contentType <- map["Content-Type"]
    }
    
}

enum Router: URLRequestConvertible {
    case endpoint(EndpointAccess, param: Mappable?)
    case upload(endpoint: EndpointAccess)
    
    var param: Mappable? {
        switch self {
        case .endpoint(_, param: let param):
            return param
        default:
            return nil
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .endpoint(let path, param: _):
            return path.method
        case .upload(endpoint: let path):
            return path.method
        }
    }

    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .endpoint( path, param: param):
            let requestURL = Foundation.URL(string: path.URL())
            var request = Foundation.URLRequest(url: requestURL!)
            let header = Header().toJSON() as! [String: String]
            header.forEach({ (key, value) in
                request.setValue(value, forHTTPHeaderField: key)
            })
            request.httpMethod = path.method.rawValue
            request.timeoutInterval = 10.0
            var params: [String: Any] = [:]
            if let dic = param?.toJSON(), !dic.isEmpty {
                for (key, value) in dic {
                    params[key] = value
                }
            }
            if path.method == .post {
                return try JSONEncoding.default.encode(request, withJSONObject: params).urlRequest!
            } else if path.method == .get {
                return try URLEncoding.queryString.encode(urlRequest!, with: params)
            } else {
                return  try JSONEncoding.default.encode(request, withJSONObject: params).urlRequest!
            }
        case .upload(endpoint: let path):
            let header = Header().toJSON() as! [String: String]
            let requestURL = Foundation.URL(string: path.URL())
            var request = Foundation.URLRequest(url: requestURL!)
            request.httpMethod = path.method.rawValue
            request.timeoutInterval = 10.0
            header.forEach({ (key, value) in
                request.setValue(value, forHTTPHeaderField: key)
            })
            return try JSONEncoding.default.encode(request, withJSONObject: param).urlRequest!
        }
    }
    
}

class RequestManager {
    static func reques<T: Mappable>(_ router: Router) -> Observable<T> {
        return Observable.create({ observer -> Disposable in
            Alamofire
                .request(router.urlRequest!)
                .responseString(completionHandler: { response in
                    let error = AppError()
                    switch response.result {
                    case .success (let value):
                        if let obj = Mapper<T>().map(JSONString: value) {
                            observer.onNext(obj)
                            observer.onCompleted()
                        } else {
                            observer.on(.error(error))
                        }
                    case .failure(let error):
                         observer.on(.error(error))
                    }
                })
            return Disposables.create()
        })
    }

}

