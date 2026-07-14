import { ValueType } from '@kit.ArkData'

type EventName = "item:add" | "item:remove" | "item:update" | "card:launch"
type EmitterEvent = Record<EventName, Array<EventFn>>

export type EventArg = Record<string, ValueType>
type EventFn = (args?: object) => void

interface ListenerEntry {
  id: string
  eventName: EventName
  callback: EventFn
}

class EventEmitter {
  events: EmitterEvent = {} as EmitterEvent
  private listeners: ListenerEntry[] = []

  private generateId(): string {
    const timestamp: string = Date.now().toString()
    const random: string = Math.floor(Math.random() * 100000).toString()
    return 'listener_' + timestamp + '_' + random
  }

  /**
   * Subscribe to an event with a unique listener ID.
   * Returns a string ID that can be used with unsubscribe(id) to
   * remove only this specific listener.
   */
  subscribe(eventName: EventName, callback: EventFn): string {
    const id: string = this.generateId()
    const entry: ListenerEntry = {
      id: id,
      eventName: eventName,
      callback: callback
    }
    this.listeners.push(entry)

    // Also register via on() for backward compatibility
    if (!this.events[eventName]) {
      this.events[eventName] = []
    }
    this.events[eventName].push(callback)

    return id
  }

  /**
   * Unsubscribe a specific listener by its ID.
   * Only removes the exact listener matching this ID.
   */
  unsubscribe(id: string): void {
    const index: number = this.listeners.findIndex(entry => entry.id === id)
    if (index < 0) {
      return
    }
    const entry: ListenerEntry = this.listeners[index]
    this.listeners.splice(index, 1)

    // Also remove from the events array for consistency
    if (this.events[entry.eventName]) {
      const cbIndex: number = this.events[entry.eventName].indexOf(entry.callback)
      if (cbIndex >= 0) {
        this.events[entry.eventName].splice(cbIndex, 1)
      }
    }
  }

  on(eventName: EventName, callback: EventFn): void {
    if (!this.events[eventName]) {
      this.events[eventName] = []
    }
    this.events[eventName].push(callback)
  }

  off(eventName: EventName, callback?: EventFn): void {
    if (this.events[eventName]) {
      if (callback) {
        const idx: number = this.events[eventName].indexOf(callback)
        if (idx >= 0) {
          this.events[eventName].splice(idx, 1)
          // Also remove from listeners if present
          const listenerIdx: number = this.listeners.findIndex(
            entry => entry.eventName === eventName && entry.callback === callback
          )
          if (listenerIdx >= 0) {
            this.listeners.splice(listenerIdx, 1)
          }
        }
      } else {
        this.events[eventName] = []
        // Also remove from listeners
        this.listeners = this.listeners.filter(entry => entry.eventName !== eventName)
      }
    }
  }

  emit(eventName: EventName, args?: EventArg): void {
    if (this.events[eventName]) {
      const callbacks = this.events[eventName]
      for (let i = 0; i < callbacks.length; i++) {
        callbacks[i](args)
      }
    }
  }

}

export const eventEmitter = new EventEmitter()
