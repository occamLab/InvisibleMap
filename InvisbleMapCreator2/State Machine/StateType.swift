//
//  StateType.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation

protocol StateType {
    /// Events are effectful inputs from the outside world which the state reacts to, described by some
    /// data type. For instance: a button being clicked, or some network data arriving.
    associatedtype InputEvent

    /// Commands are effectful outputs which the state desires to have performed on the outside world.
    /// For instance: showing an alert, transitioning to some different UI, etc.
    associatedtype OutputCommand

    /// In response to an event, a state may transition to some new value, and it may emit a command.
    mutating func handleEvent(event: InputEvent) -> [OutputCommand]

    // If you're not familiar with Swift, the mutation semantics here may seem like a very big red
    // flag, destroying the purity of this type. In fact, because states have *value semantics*,
    // mutation becomes mere syntax sugar. From a semantic perspective, any call to this method
    // creates a new instance of StateType; no code other than the caller has visibility to the
    // change; the normal perils of mutability do not apply.
    //
    // If this is confusing, keep in mind that we could equivalently define this as a function
    // which returns both a new state value and an optional OutputCommand (it just creates some
    // line noise later):
    //   func handleEvent(event: InputEvent) -> (Self, OutputCommand)

    /// State machines must specify an initial value.
    static var initialState: Self { get }

    // Traditional models often allow states to specific commands to be performed on entry or
    // exit. We could add that, or not.
}
