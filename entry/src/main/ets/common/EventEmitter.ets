import { ValueType } from '@kit.ArkData'

type EventName = "item:add" | "item:remove" | "item:update"
type EmitterEvent = Record<EventName, Array<Function>>

export type EventArg = Record<string, ValueType>
type EventFn = (args?:object)=>void

interface AbsEventEmitter {
  events: EmitterEvent
  on(eventName: EventName, callback: Function): void
  off(eventName: EventName, callback?: Function): void
  emit(eventName: EventName, args?: EventArg): void
}

export const EventMap: Record<EventName, string> = {
  "item:add": "work:add",
  "item:remove": "item:remove",
  "item:update": "work:update",
}

class EventEmitter implements AbsEventEmitter {
  events: EmitterEvent = {} as EmitterEvent

  on(eventName: EventName, callback: EventFn) {
    if (!this.events[eventName]) {
      this.events[eventName] = [];
    }
    this.events[eventName].push(callback);
  }

  off(eventName: EventName, callback?: EventFn) {
    if (this.events[eventName]) {
      if (callback) {
        const idx = this.events[eventName].indexOf(callback)
        if (idx >= 0) {
          this.events[eventName].splice(idx, 1)
        }
      } else {
        this.events[eventName] = []
      }
    }
  }

  emit(eventName: EventName, args?: EventArg) {
    if (this.events[eventName]) {
      this.events[eventName].forEach(callback => {
        callback(args)
      });
    }
  }

}

export const eventEmitter = new EventEmitter()
