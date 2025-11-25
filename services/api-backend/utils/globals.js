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
          if (prop === 'safeSplice' && Array.isArray(args[0])) {
            return args[0].splice(args[1], args[2], ...args.slice(3));
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
          if (prop === 'safeJoin' && Array.isArray(args[0])) {
            return args[0].join(args[1] || ',');
          }
          if (prop === 'safeSplit' && typeof args[0] === 'string') {
            return args[0].split(args[1] || ',');
          }
          if (prop === 'safeNormalize' && typeof args[0] === 'string') {
            return args[0].normalize(args[1] || 'NFC');
          }
          if (prop === 'safeToUpperCase' && typeof args[0] === 'string') {
            return args[0].toUpperCase();
          }
          if (prop === 'safeToLowerCase' && typeof args[0] === 'string') {
            return args[0].toLowerCase();
          }
          if (prop === 'safeTrim' && typeof args[0] === 'string') {
            return args[0].trim();
          }
          if (prop === 'safeReplace' && typeof args[0] === 'string') {
            return args[0].replace(args[1], args[2]);
          }
          if (prop === 'safeIncludes') {
            if (Array.isArray(args[0])) {
              return args[0].includes(args[1]);
            }
            if (typeof args[0] === 'string') {
              return args[0].includes(args[1]);
            }
            return false;
          }
          if (prop === 'safeIndexOf') {
            if (Array.isArray(args[0])) {
              return args[0].indexOf(args[1]);
            }
            if (typeof args[0] === 'string') {
              return args[0].indexOf(args[1]);
            }
            return -1;
          }
          if (prop === 'safeLastIndexOf') {
            if (Array.isArray(args[0])) {
              return args[0].lastIndexOf(args[1]);
            }
            if (typeof args[0] === 'string') {
              return args[0].lastIndexOf(args[1]);
            }
            return -1;
          }
          if (prop === 'safeStartsWith' && typeof args[0] === 'string') {
            return args[0].startsWith(args[1]);
          }
          if (prop === 'safeEndsWith' && typeof args[0] === 'string') {
            return args[0].endsWith(args[1]);
          }
          if (prop === 'safeSubstring' && typeof args[0] === 'string') {
            return args[0].substring(args[1], args[2]);
          }
          if (prop === 'safeSubstr' && typeof args[0] === 'string') {
            return args[0].substr(args[1], args[2]);
          }
          if (prop === 'safeCharAt' && typeof args[0] === 'string') {
            return args[0].charAt(args[1]);
          }
          if (prop === 'safeCharCodeAt' && typeof args[0] === 'string') {
            return args[0].charCodeAt(args[1]);
          }
          if (prop === 'safeConcat') {
            if (Array.isArray(args[0])) {
              return args[0].concat(...args.slice(1));
            }
            if (typeof args[0] === 'string') {
              return args[0].concat(...args.slice(1));
            }
            return args[0];
          }
          if (prop === 'safeRepeat' && typeof args[0] === 'string') {
            return args[0].repeat(args[1] || 1);
          }
          if (prop === 'safePadStart' && typeof args[0] === 'string') {
            return args[0].padStart(args[1], args[2]);
          }
          if (prop === 'safePadEnd' && typeof args[0] === 'string') {
            return args[0].padEnd(args[1], args[2]);
          }
          if (prop === 'safeMatch' && typeof args[0] === 'string') {
            return args[0].match(args[1]);
          }
          if (prop === 'safeSearch' && typeof args[0] === 'string') {
            return args[0].search(args[1]);
          }
          if (prop === 'safeLocaleCompare' && typeof args[0] === 'string') {
            return args[0].localeCompare(args[1]);
          }
          if (prop === 'safeSort' && Array.isArray(args[0])) {
            return args[0].sort(args[1]);
          }
          if (prop === 'safeReverse' && Array.isArray(args[0])) {
            return args[0].reverse();
          }
          if (prop === 'safeSome' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].some(args[1]);
          }
          if (prop === 'safeEvery' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].every(args[1]);
          }
          if (prop === 'safeReduce' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].reduce(args[1], args[2]);
          }
          if (prop === 'safeReduceRight' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].reduceRight(args[1], args[2]);
          }
          if (prop === 'safeFill' && Array.isArray(args[0])) {
            return args[0].fill(args[1], args[2], args[3]);
          }
          if (prop === 'safeCopyWithin' && Array.isArray(args[0])) {
            return args[0].copyWithin(args[1], args[2], args[3]);
          }
          if (prop === 'safeFlat' && Array.isArray(args[0])) {
            return args[0].flat(args[1]);
          }
          if (prop === 'safeFlatMap' && Array.isArray(args[0]) && typeof args[1] === 'function') {
            return args[0].flatMap(args[1]);
          }
          if (prop === 'safeAt' && (Array.isArray(args[0]) || typeof args[0] === 'string')) {
            return args[0].at(args[1]);
          }
          if (prop === 'safeWith' && Array.isArray(args[0])) {
            return args[0].with(args[1], args[2]);
          }
          if (prop === 'safeToReversed' && Array.isArray(args[0])) {
            return args[0].toReversed();
          }
          if (prop === 'safeToSorted' && Array.isArray(args[0])) {
            return args[0].toSorted(args[1]);
          }
          if (prop === 'safeToSpliced' && Array.isArray(args[0])) {
            return args[0].toSpliced(args[1], args[2], ...args.slice(3));
          }
          if (prop === 'safeLength') {
            if (Array.isArray(args[0]) || typeof args[0] === 'string') {
              return args[0].length;
            }
            return 0;
          }
          if (prop === 'safeIsArray') {
            return Array.isArray(args[0]);
          }
          if (prop === 'safeIsObject') {
            return args[0] !== null && typeof args[0] === 'object';
          }
          if (prop === 'safeIsString') {
            return typeof args[0] === 'string';
          }
          if (prop === 'safeIsNumber') {
            return typeof args[0] === 'number';
          }
          if (prop === 'safeIsBoolean') {
            return typeof args[0] === 'boolean';
          }
          if (prop === 'safeIsFunction') {
            return typeof args[0] === 'function';
          }
          if (prop === 'safeIsUndefined') {
            return args[0] === undefined;
          }
          if (prop === 'safeIsNull') {
            return args[0] === null;
          }
          if (prop === 'safeIsNullOrUndefined') {
            return args[0] === null || args[0] === undefined;
          }
          if (prop === 'safeIsEmpty') {
            if (Array.isArray(args[0]) || typeof args[0] === 'string') {
              return args[0].length === 0;
            }
            if (typeof args[0] === 'object' && args[0] !== null) {
              return Object.keys(args[0]).length === 0;
            }
            return false;
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
const globalsProxy = new globalThis.Proxy({}, handler);

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
export const Int8Array = globalThis.Int8Array;
export const Uint8ClampedArray = globalThis.Uint8ClampedArray;
export const Int16Array = globalThis.Int16Array;
export const Uint16Array = globalThis.Uint16Array;
export const Int32Array = globalThis.Int32Array;
export const Uint32Array = globalThis.Uint32Array;
export const Float32Array = globalThis.Float32Array;
export const Float64Array = globalThis.Float64Array;
export const BigInt64Array = globalThis.BigInt64Array;
export const BigUint64Array = globalThis.BigUint64Array;

// Export safe functions
export const safeMap = globalsProxy.safeMap;
export const safePush = globalsProxy.safePush;
export const safeSlice = globalsProxy.safeSlice;
export const safeSplice = globalsProxy.safeSplice;
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
export const safeNormalize = globalsProxy.safeNormalize;
export const safeJoin = globalsProxy.safeJoin;
export const safeSplit = globalsProxy.safeSplit;
export const safeToUpperCase = globalsProxy.safeToUpperCase;
export const safeToLowerCase = globalsProxy.safeToLowerCase;
export const safeTrim = globalsProxy.safeTrim;
export const safeReplace = globalsProxy.safeReplace;
export const safeIncludes = globalsProxy.safeIncludes;
export const safeIndexOf = globalsProxy.safeIndexOf;
export const safeLastIndexOf = globalsProxy.safeLastIndexOf;
export const safeStartsWith = globalsProxy.safeStartsWith;
export const safeEndsWith = globalsProxy.safeEndsWith;
export const safeSubstring = globalsProxy.safeSubstring;
export const safeSubstr = globalsProxy.safeSubstr;
export const safeCharAt = globalsProxy.safeCharAt;
export const safeCharCodeAt = globalsProxy.safeCharCodeAt;
export const safeConcat = globalsProxy.safeConcat;
export const safeRepeat = globalsProxy.safeRepeat;
export const safePadStart = globalsProxy.safePadStart;
export const safePadEnd = globalsProxy.safePadEnd;
export const safeMatch = globalsProxy.safeMatch;
export const safeSearch = globalsProxy.safeSearch;
export const safeLocaleCompare = globalsProxy.safeLocaleCompare;
export const safeSort = globalsProxy.safeSort;
export const safeReverse = globalsProxy.safeReverse;
export const safeSome = globalsProxy.safeSome;
export const safeEvery = globalsProxy.safeEvery;
export const safeReduce = globalsProxy.safeReduce;
export const safeReduceRight = globalsProxy.safeReduceRight;
export const safeFill = globalsProxy.safeFill;
export const safeCopyWithin = globalsProxy.safeCopyWithin;
export const safeFlat = globalsProxy.safeFlat;
export const safeFlatMap = globalsProxy.safeFlatMap;
export const safeAt = globalsProxy.safeAt;
export const safeWith = globalsProxy.safeWith;
export const safeToReversed = globalsProxy.safeToReversed;
export const safeToSorted = globalsProxy.safeToSorted;
export const safeToSpliced = globalsProxy.safeToSpliced;
export const safeLength = globalsProxy.safeLength;
export const safeIsArray = globalsProxy.safeIsArray;
export const safeIsObject = globalsProxy.safeIsObject;
export const safeIsString = globalsProxy.safeIsString;
export const safeIsNumber = globalsProxy.safeIsNumber;
export const safeIsBoolean = globalsProxy.safeIsBoolean;
export const safeIsFunction = globalsProxy.safeIsFunction;
export const safeIsUndefined = globalsProxy.safeIsUndefined;
export const safeIsNull = globalsProxy.safeIsNull;
export const safeIsNullOrUndefined = globalsProxy.safeIsNullOrUndefined;
export const safeIsEmpty = globalsProxy.safeIsEmpty;
