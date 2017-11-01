//
//  TransformTests.swift
//  DLVM
//
//  Created by Richard Wei on 4/27/17.
//
//

import XCTest
@testable import DLVM

class TransformTests: XCTestCase {
    
    let builder = IRBuilder(moduleName: "TransformTest")
    
    /// - TODO: Fix bug in dominance analysis that causes crash
    func testDCE() throws {
        let fun = builder.buildFunction(named: "bar",
                                        argumentTypes: [.scalar(.float(.single)), .scalar(.float(.single))],
                                        returnType: .int(32))
        builder.move(to: builder.buildEntry(argumentNames: ["x", "y"], in: fun))
        let mult = builder.multiply(.literal(.int(32), 5), .literal(.int(32), 8))
        let dead1 = builder.buildInstruction(.numericBinary(.multiply,
                                                            .literal(.int(32), 10000), .literal(.int(32), 20000)),
                                             name: "dead1")
        builder.buildInstruction(.numericBinary(.add, %dead1, 20000 ~ Type.int(32)),
                                 name: "dead2")
        let cmp = builder.compare(.equal, %mult, .literal(.int(32), 1))
        let thenBB = builder.buildBasicBlock(named: "then", arguments: [ "x" : .int(32) ], in: fun)
        let elseBB = builder.buildBasicBlock(named: "else", arguments: [ "x" : .int(32) ], in: fun)
        let contBB = builder.buildBasicBlock(named: "cont", arguments: [ "x" : .int(32) ], in: fun)
        builder.conditional(%cmp, then: thenBB, arguments: [.literal(.int(32), 0)],
                            else: elseBB, arguments: [.literal(.int(32), 1)])
        builder.move(to: thenBB)
        builder.branch(contBB, [ %thenBB.arguments[0] ])
        builder.move(to: elseBB)
        builder.branch(contBB, [ %elseBB.arguments[0] ])
        builder.move(to: contBB)
        builder.return(%contBB.arguments[0])
        
        /// Original:
        /// func @bar: (f32, f32) -> i32 {
        /// 'entry(%x: f32, %y : f32):
        ///     %0.0 = multiply 5: i32, 8: i32
        ///     %dead1 = multiply 10000: i32, 20000: i32
        ///     %dead2 = add %dead1: i32, 20000: i32
        ///     %0.3 = equal %v0: i32, 1: i32
        ///     conditional %v1: bool then 'then(0: i32) else 'else(1: i32)
        /// 'then(%x: i32):
        ///     branch 'cont(%x: i32)
        /// 'else(%x: i32):
        ///     branch 'cont(%x: i32)
        /// 'cont(%x: i32):
        ///     return %x: i32
        /// }

        let module = builder.module
        module.mapTransform(DeadCodeElimination.self)
        let after = """
            func @bar: (f32, f32) -> i32 {
            'entry(%x: f32, %y: f32):
                %0.0 = multiply 5: i32, 8: i32
                %0.1 = equal %0.0: i32, 1: i32
                conditional %0.1: bool then 'then(0: i32) else 'else(1: i32)
            'then(%x: i32):
                branch 'cont(%x: i32)
            'else(%x: i32):
                branch 'cont(%x: i32)
            'cont(%x: i32):
                return %x: i32
            }
            """
        XCTAssertEqual(fun.description, after)

        /// Reapplying shouldn't mutate the function
        XCTAssertFalse(module.mapTransform(AlgebraSimplification.self))
    }

    func testAlgebraSimplification() {
        let fun = builder.buildFunction(named: "foo",
                                        argumentTypes: [.scalar(.int(32)), .scalar(.int(32))],
                                        returnType: .int(32))
        let entry = builder.buildEntry(argumentNames: ["x", "y"], in: fun)
        builder.move(to: entry)
        
        /// Arithmetics
        /// Neutral/absorbing expressions
        let x = %entry.arguments[0]
        /// x + 0 | 0 + x | x - 0 | x * 1 | 1 * x | x / 1 => x
        let a0 = builder.add(x, .literal(.int(32), 0))
        let a1 = builder.add(.literal(.int(32), 0), %a0)
        let a2 = builder.subtract(%a1, .literal(.int(32), 0))
        let a3 = builder.multiply(%a2, .literal(.int(32), 1))
        let a4 = builder.multiply(.literal(.int(32), 1), %a3)
        let a5 = builder.divide(%a4, .literal(.int(32), 1))
        /// - x * 0 | 0 * x => 0
        let b0 = builder.multiply(x, .literal(.int(32), 0))
        let b1 = builder.multiply(%b0, x)
        let b2 = builder.add(%b1, %a5)
        /// - x^0 => 1
        /// - x^1 => x
        let c0 = builder.power(%b2, .literal(.int(32), 0))
        let c1 = builder.power(%b2, %c0)

        /// Same argument reduction
        /// - x - x => 0
        let d0 = builder.subtract(x, x)
        /// - x / x => 1
        let d1 = builder.divide(x, x)
        let d2 = builder.multiply(%d0, %d1)
        let d3 = builder.add(%c1, %d2)

        builder.return(%d3)

        let module = builder.module
        var changed = true
        while (changed) {
            changed = module.mapTransform(AlgebraSimplification.self)
        }

        let after = """
            func @foo: (i32, i32) -> i32 {
            'entry(%x: i32, %y: i32):
                return %x: i32
            }
            """
        XCTAssertEqual(fun.description, after)

        /// Reapplying shouldn't mutate the function
        XCTAssertFalse(module.mapTransform(AlgebraSimplification.self))
    }
    
    static var allTests : [(String, (TransformTests) -> () throws -> Void)] {
        return [
            ("testDCE", testDCE),
            ("testAlgebraSimplification", testAlgebraSimplification),
        ]
    }
    
}
