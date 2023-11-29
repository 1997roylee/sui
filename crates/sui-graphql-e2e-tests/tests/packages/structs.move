// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

//# init --addresses P0=0x0 P1=0x0 --accounts A --simulator

//# run-graphql

# Tests on existing system types
{
    object(address: "0x2") {
        asMovePackage {
            # Look-up a type that has generics, including phantoms.
            coin: module(name: "coin") {
                struct(name: "Coin") {
                    name
                    abilities
                    typeParameters {
                        constraints
                        isPhantom
                    }
                    fields {
                        name
                        type {
                            repr
                            signature
                        }
                    }
                }
            }

            tx_context: module(name: "tx_context") {
                struct(name: "TxContext") {
                    name
                    abilities
                    typeParameters {
                        constraints
                        isPhantom
                    }
                    fields {
                        name
                        type {
                            repr
                            signature
                        }
                    }
                }
            }
        }
    }
}

//# publish --upgradeable --sender A

module P0::m {
    struct S has copy, drop { x: u64 }
}

//# create-checkpoint

//# run-graphql

# Check the contents of P0::m::S that was just published, this acts as
# a reference for when we run the same transaction against the
# upgraded package.
fragment Structs on Object {
    location
    asMovePackage {
        module(name: "m") {
            struct(name: "S") {
                name
                abilities
                typeParameters {
                    constraints
                    isPhantom
                }
                fields {
                    name
                    type {
                        repr
                        signature
                    }
                }
            }
        }
    }
}

{
    transactionBlockConnection(last: 1) {
        nodes {
            effects {
                objectChanges {
                    outputState {
                        ...Structs
                    }
                }
            }
        }
    }
}

//# upgrade --package P0 --upgrade-capability 2,1 --sender A

module P1::m {
    struct S has copy, drop { x: u64 }
    struct T<U: drop> { y: u64, s: S, u: U }
    struct V { t: T<S> }
}

//# create-checkpoint

//# run-graphql

# Run a similar query as above again, but on the upgraded package, to
# see the IDs of types as they appear in the new package -- they will
# all be the runtime ID.
fragment FullStruct on MoveStruct {
    module { moduleId { package { asObject { location } } } }
    name
    abilities
    typeParameters {
        constraints
        isPhantom
    }
    fields {
        name
        type {
            repr
            signature
        }
    }
}

fragment Structs on Object {
    location
    asMovePackage {
        module(name: "m") {
            s: struct(name: "S") { ...FullStruct }
            t: struct(name: "T") { ...FullStruct }

            # V is a special type that exists to show the
            # representations of S and T, so we don't need to query as
            # many fields for it.
            v: struct(name: "V") {
                name
                fields {
                    name
                    type { repr }
                }
            }
        }
    }
}

{
    transactionBlockConnection(last: 1) {
        nodes {
            effects {
                objectChanges {
                    outputState {
                        ...Structs
                    }
                }
            }
        }
    }
}

//# run-graphql

# But we can still confirm that we can roundtrip the `T` struct from
# its own module, but cannot reach `T` from `S`'s defining module.

fragment ReachT on MoveStruct {
    module { struct(name: "T") { name } }
}

fragment Structs on Object {
    asMovePackage {
        module(name: "m") {
            # S should not be able to reach T from its own module
            s: struct(name: "S") { ...ReachT }

            # But T should
            t: struct(name: "T") { ...ReachT }
        }
    }
}

{
    transactionBlockConnection(last: 1) {
        nodes {
            effects {
                objectChanges {
                    outputState {
                        ...Structs
                    }
                }
            }
        }
    }

}