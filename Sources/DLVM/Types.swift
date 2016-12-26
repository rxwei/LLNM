//
//  Types.swift
//  DLVM
//
//  Created by Richard Wei on 12/20/16.
//
//

public enum DataType : String {
    case int8 = "int8"
    case int16 = "int16"
    case int32 = "int32"
    case int64 = "int64"
    case float8 = "float8"
    case float16 = "float16"
    case float32 = "float32"
    case float64 = "float64"

    public var isInt: Bool {
        switch self {
        case .int8, .int16, .int32, .int64:
            return true
        default:
            return false
        }
    }

    public var isFloat: Bool {
        return !isInt
    }
}

public enum ScalarType {
    case bool, int, float
}

public protocol TensorBase {
    static var dataType: DataType { get }
}
