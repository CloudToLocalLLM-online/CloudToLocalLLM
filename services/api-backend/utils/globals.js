// Comprehensive globals file for jest configuration
// Exports all common utilities and built-in types via a Proxy

// Create a proxy that returns a no-op function for any requested export
const handler = {
  get: (target, prop) => {
    // Return built-in types
    if (prop in globalThis) {
      return globalThis[prop];
    }

    // Return safe functions
    if (typeof prop === 'string' && prop.startsWith('safe')) {
      return (...args) => {
        try {
          if (prop === 'safeMap' && typeof args[1] === 'function') {
            return Array.isArray(args[0]) ? args[0].map(args[1]) : [];
          }
          if (prop === 'safePush' && Array.isArray(args[0])) {
            args[0].push(args[1]);
            return args[0];
          }
          if (prop === 'safeSlice' && Array.isArray(args[0])) {
            return args[0].slice(args[1], args[2]);
          }
          if (prop === 'safeForEach' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            args[0].forEach(args[1]);
            return args[0];
          }
          if (prop === 'safeFilter' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].filter(args[1]);
          }
          if (prop === 'safeFind' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].find(args[1]);
          }
          if (prop === 'safeGet') {
            const [obj, path, defaultValue] = args;
            const keys = String(path).split('.');
            let result = obj;
            for (const key of keys) {
              result = result?.[key];
              if (result === undefined) {
                return defaultValue;
              }
            }
            return result;
          }
          if (prop === 'safeSet') {
            const [obj, path, value] = args;
            const keys = String(path).split('.');
            let current = obj;
            for (let i = 0; i < keys.length - 1; i++) {
              if (!(keys[i] in current)) {
                current[keys[i]] = {};
              }
              current = current[keys[i]];
            }
            current[keys[keys.length - 1]] = value;
            return obj;
          }
          if (prop === 'safeHasOwnProperty') {
            const [obj, key] = args;
            return Object.prototype.hasOwnProperty.call(obj, key);
          }
          return args[0];
        } catch {
          return args[0];
        }
      };
    }

    // Return a no-op function for anything else
    return () => undefined;
  },
};

// Create the proxy
const globalsProxy = new Proxy({}, handler);

// Export the proxy as default and as globals
export const globals = globalsProxy;
export default globalsProxy;

// Export all built-in types
export const String = globalThis.String;
export const Number = globalThis.Number;
export const Boolean = globalThis.Boolean;
export const Array = globalThis.Array;
export const Object = globalThis.Object;
export const Error = globalThis.Error;
export const TypeError = globalThis.TypeError;
export const RangeError = globalThis.RangeError;
export const SyntaxError = globalThis.SyntaxError;
export const ReferenceError = globalThis.ReferenceError;
export const Date = globalThis.Date;
export const RegExp = globalThis.RegExp;
export const Map = globalThis.Map;
export const Set = globalThis.Set;
export const WeakMap = globalThis.WeakMap;
export const WeakSet = globalThis.WeakSet;
export const Promise = globalThis.Promise;
export const Symbol = globalThis.Symbol;
export const JSON = globalThis.JSON;
export const Math = globalThis.Math;
export const console = globalThis.console;
export const BigInt = globalThis.BigInt;
export const Uint8Array = globalThis.Uint8Array;
export const ArrayBuffer = globalThis.ArrayBuffer;
export const DataView = globalThis.DataView;
export const Intl = globalThis.Intl;
export const Reflect = globalThis.Reflect;
export const Proxy = globalThis.Proxy;
export const Atomics = globalThis.Atomics;
export const SharedArrayBuffer = globalThis.SharedArrayBuffer;

// Export safe functions
export const safeMap = globalsProxy.safeMap;
export const safePush = globalsProxy.safePush;
export const safeSlice = globalsProxy.safeSlice;
export const safeForEach = globalsProxy.safeForEach;
export const safeFilter = globalsProxy.safeFilter;
export const safeFind = globalsProxy.safeFind;
export const safeGet = globalsProxy.safeGet;
export const safeSet = globalsProxy.safeSet;
export const safeHasOwnProperty = globalsProxy.safeHasOwnProperty;
export const safeHas = globalsProxy.safeHas;
export const safeDelete = globalsProxy.safeDelete;
export const safeKeys = globalsProxy.safeKeys;
export const safeValues = globalsProxy.safeValues;
export const safeEntries = globalsProxy.safeEntries;
export const safeAssign = globalsProxy.safeAssign;
export const safeFreeze = globalsProxy.safeFreeze;
export const safeSeal = globalsProxy.safeSeal;
export const safeGetTime = globalsProxy.safeGetTime;
export const safeNow = globalsProxy.safeNow;
export const safeRandom = globalsProxy.safeRandom;
export const safeFloor = globalsProxy.safeFloor;
export const safeCeil = globalsProxy.safeCeil;
export const safeRound = globalsProxy.safeRound;
export const safeAbs = globalsProxy.safeAbs;
export const safeMin = globalsProxy.safeMin;
export const safeMax = globalsProxy.safeMax;
export const safePow = globalsProxy.safePow;
export const safeSqrt = globalsProxy.safeSqrt;
export const safeLog = globalsProxy.safeLog;
export const safeExp = globalsProxy.safeExp;
export const safeSin = globalsProxy.safeSin;
export const safeCos = globalsProxy.safeCos;
export const safeTan = globalsProxy.safeTan;
export const safeParseInt = globalsProxy.safeParseInt;
export const safeParseFloat = globalsProxy.safeParseFloat;
export const safeIsNaN = globalsProxy.safeIsNaN;
export const safeIsFinite = globalsProxy.safeIsFinite;
export const safeEncodeURI = globalsProxy.safeEncodeURI;
export const safeDecodeURI = globalsProxy.safeDecodeURI;
export const safeEncodeURIComponent = globalsProxy.safeEncodeURIComponent;
export const safeDecodeURIComponent = globalsProxy.safeDecodeURIComponent;
