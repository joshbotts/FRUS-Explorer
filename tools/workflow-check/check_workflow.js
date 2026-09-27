// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Syntax and smoke check for a Workflow script in .claude/workflows/, run through macOS's own
// JavaScriptCore because this machine has no node (#1512).
//
//   osascript -l JavaScript tools/workflow-check/check_workflow.js .claude/workflows/<name>.js '<args JSON>'
//
// 1. The file must begin with `export const meta = {`, and the meta object must evaluate in an
//    empty scope: a pure literal, with no identifier, call or template.
// 2. It must not use Date.now(), Math.random() or new Date(, which a workflow cannot.
// 3. The body, with `export ` removed, must parse as an async function body (top-level await and
//    return are legal in a workflow).
// 4. The body is then RUN against stub hooks with the given args. Each stub agent returns an object
//    shaped by its schema, and a prompt containing the text "undefined" fails the run, so a name the
//    script never defined, or an argument the example did not supply, is caught on the happy path.
//    That holds inside parallel() and pipeline() too: their stubs still return null for a thunk or
//    stage that throws (the scripts filter those out), but record the error, and any recorded error
//    fails the check (#1512 review round 1: before, lane-dev.js's Review and Verify and all of
//    open-issue-review.js could read "undefined" and still pass). It prints "OK <file>: …" with
//    the agent calls and phases, or "FAIL: …". A phase used but not declared in meta.phases is
//    reported as UNDECLARED, and a declared phase the run never reached as UNREACHED.
// Every verdict line goes to stderr (JXA's console.log), and the checker exits 0 on OK and 1 on
// FAIL. JXA drains the microtask queue only after run() returns, so step 4's verdict is printed
// from the promise's callbacks, which exit before osascript prints run()'s return value. That value
// reaches stdout only when step 4 never settles, and then says so, with exit status 0.
ObjC.import('Foundation')
ObjC.import('stdlib')

function verdict(line) {
  console.log(line)
  $.exit(line.startsWith('OK ') ? 0 : 1)
}

function readFile(p) {
  const s = $.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null)
  if (s.isNil()) throw new Error('cannot read ' + p)
  return ObjC.unwrap(s)
}

function run(argv) {
  const path = argv[0]
  const args = JSON.parse(argv[1] || '{}')
  const src = readFile(path)
  if (!src.startsWith('export const meta = {')) return verdict('FAIL: does not begin with export const meta = {')
  let i = src.indexOf('{'), depth = 0, q = null
  for (; i < src.length; i++) {
    const c = src[i]
    if (q) { if (c === '\\') { i++; continue } if (c === q) q = null; continue }
    if (c === "'" || c === '"' || c === '`') { q = c; continue }
    if (c === '{') depth++
    else if (c === '}') { depth--; if (depth === 0) break }
  }
  const metaSrc = src.slice(src.indexOf('{'), i + 1)
  if (metaSrc.includes('`')) return verdict('FAIL: meta uses a template literal')
  let meta
  try { meta = Function('"use strict"; return (' + metaSrc + ')')() } catch (e) { return verdict('FAIL: meta is not a pure literal: ' + e) }
  if (!meta.name || !meta.description) return verdict('FAIL: meta lacks name or description')
  for (const bad of ['Date.now', 'Math.random', 'new Date(']) if (src.includes(bad)) return verdict('FAIL: uses ' + bad)
  const body = src.replace(/^export const meta/, 'const meta')
  let fn
  try { fn = eval('(async function (args, agent, parallel, pipeline, phase, log, budget, workflow) {\n' + body + '\n})') }
  catch (e) { return verdict('FAIL: syntax: ' + e) }

  const calls = []
  const phases = new Set()
  const logs = []
  const swallowed = []   // errors the stub parallel() and pipeline() turned into null
  const numbers = (args.newer || []).concat(args.older || [])
  function fake(schema) {
    if (!schema) return 'stub text'
    const props = schema.properties || {}
    const o = {}
    for (const k of Object.keys(props)) {
      const t = props[k].type
      if (t === 'string') o[k] = props[k].enum ? props[k].enum[0] : 'stub-' + k
      else if (t === 'boolean') o[k] = true
      else if (t === 'integer' || t === 'number') o[k] = 1
      else if (t === 'array') {
        const it = props[k].items || {}
        o[k] = it.type === 'object' ? [fake(it)] : it.type === 'integer' ? [1] : ['stub']
      } else if (t === 'object') o[k] = fake(props[k])
    }
    return o
  }
  const agent = async (prompt, opts) => {
    if (typeof prompt !== 'string' || !prompt.length) throw new Error('agent called without a prompt')
    const u = prompt.indexOf('undefined')
    if (u >= 0) throw new Error('prompt of ' + (opts && opts.label) + ' contains "undefined": …' + prompt.slice(Math.max(0, u - 80), u + 20))
    calls.push(opts && opts.label)
    if (opts && opts.phase) phases.add(opts.phase)
    const r = fake(opts && opts.schema)
    if (r && r.prs) r.prs.forEach(p => { p.worktree = '/stub/worktree'; p.branch = 'stub-branch'; p.diffPath = '/stub/x.diff' })
    if (r && r.issues) r.issues.forEach(x => { x.number = numbers[0] || 1 })
    if (r && r.verdicts) r.verdicts.forEach(x => { x.number = numbers[0] || 1 })
    return r
  }
  const parallel = async (thunks) => Promise.all(thunks.map((t, i) =>
    Promise.resolve().then(t).catch(e => { swallowed.push('parallel thunk ' + i + ': ' + e); return null })))
  const pipeline = async (items, ...stages) => Promise.all(items.map(async (item, idx) => {
    let prev = item
    for (let k = 0; k < stages.length; k++) {
      try { prev = await stages[k](prev, item, idx) }
      catch (e) { swallowed.push('pipeline item ' + idx + ' stage ' + k + ': ' + e); return null }
    }
    return prev
  }))
  const phase = (t) => phases.add(t)
  const log = (m) => logs.push(m)
  const budget = { total: null, spent: () => 0, remaining: () => Infinity }
  fn(args, agent, parallel, pipeline, phase, log, budget, async () => null).then(result => {
    if (swallowed.length) {
      return verdict('FAIL: ' + swallowed.length + ' error(s) inside parallel() or pipeline(), each turned into null there: ' +
        swallowed.join(' | ').slice(0, 1200))
    }
    const declared = (meta.phases || []).map(p => p.title)
    const undeclared = [...phases].filter(p => !declared.includes(p))
    const unreached = declared.filter(p => !phases.has(p))
    verdict('OK ' + path.split('/').pop() + ': meta "' + meta.name + '", ' + calls.length + ' agent calls ' +
      JSON.stringify(calls) + ', phases ' + JSON.stringify([...phases]) +
      (undeclared.length ? ' UNDECLARED ' + JSON.stringify(undeclared) : '') +
      (unreached.length ? ' UNREACHED ' + JSON.stringify(unreached) : '') + ', logs ' + JSON.stringify(logs).slice(0, 300))
  }, e => verdict('FAIL: run threw: ' + e))
  // Printed only when step 4 never settles — a verdict exits before osascript prints this.
  return 'FAIL: ' + path.split('/').pop() + ' never settled: it awaited something no stub resolves (exit status 0: read this line)'
}
