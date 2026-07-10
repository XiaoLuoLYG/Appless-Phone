import socket from '@ohos.net.socket';
import util from '@ohos.util';
import { aiLogInfo } from './AiphoneLogger';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { MailDetail, MailDetailRequest, MailDraftArgs, MailSearchArgs, MailThreadResult } from './MailToolTypes';
import { utf8Bytes } from './Utf8Bytes';

export interface QqMailConfig {
  address: string;
  authCode: string;
  imapHost: string;
  imapPort: number;
  draftsMailbox: string;
}

export interface ImapTransport {
  connect(host: string, port: number): Promise<void>;
  send(line: string): Promise<void>;
  readUntil(tag: string): Promise<string[]>;
  close(): Promise<void>;
}

function bytesToBase64(bytes: Uint8Array): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const triple = (first << 16) | (second << 8) | third;
    result += alphabet.charAt((triple >> 18) & 0x3f);
    result += alphabet.charAt((triple >> 12) & 0x3f);
    result += index + 1 < bytes.length ? alphabet.charAt((triple >> 6) & 0x3f) : '=';
    result += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
  }
  return result;
}

function decodeBase64Bytes(value: string): Uint8Array {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const bytes = new Uint8Array(Math.ceil(value.length / 4) * 3);
  let byteIndex = 0;
  for (let index = 0; index < value.length; index += 4) {
    const a = alphabet.indexOf(value.charAt(index));
    const b = alphabet.indexOf(value.charAt(index + 1));
    const c = value.charAt(index + 2) === '=' ? -1 : alphabet.indexOf(value.charAt(index + 2));
    const d = value.charAt(index + 3) === '=' ? -1 : alphabet.indexOf(value.charAt(index + 3));
    if (a < 0 || b < 0) {
      continue;
    }
    const triple = (a << 18) | (b << 12) | ((c < 0 ? 0 : c) << 6) | (d < 0 ? 0 : d);
    bytes[byteIndex] = (triple >> 16) & 0xff;
    byteIndex++;
    if (c >= 0) {
      bytes[byteIndex] = (triple >> 8) & 0xff;
      byteIndex++;
    }
    if (d >= 0) {
      bytes[byteIndex] = triple & 0xff;
      byteIndex++;
    }
  }
  return bytes.slice(0, byteIndex);
}

function decodeUtf8Bytes(bytes: Uint8Array, length: number): string {
  let result = '';
  let index = 0;
  while (index < length) {
    const first = bytes[index];
    if (first < 0x80) {
      result += String.fromCharCode(first);
      index++;
    } else if ((first & 0xe0) === 0xc0 && index + 1 < length) {
      const code = ((first & 0x1f) << 6) | (bytes[index + 1] & 0x3f);
      result += String.fromCharCode(code);
      index += 2;
    } else if ((first & 0xf0) === 0xe0 && index + 2 < length) {
      const code = ((first & 0x0f) << 12) | ((bytes[index + 1] & 0x3f) << 6) | (bytes[index + 2] & 0x3f);
      result += String.fromCharCode(code);
      index += 3;
    } else if ((first & 0xf8) === 0xf0 && index + 3 < length) {
      const code = ((first & 0x07) << 18) | ((bytes[index + 1] & 0x3f) << 12) | ((bytes[index + 2] & 0x3f) << 6) | (bytes[index + 3] & 0x3f);
      const normalized = code - 0x10000;
      result += String.fromCharCode(0xd800 + (normalized >> 10));
      result += String.fromCharCode(0xdc00 + (normalized & 0x3ff));
      index += 4;
    } else {
      index++;
    }
  }
  return result;
}

export function decodeMimeWords(value: string): string {
  const marker = '=?UTF-8?B?';
  let result = value;
  let start = result.toUpperCase().indexOf(marker);
  while (start >= 0) {
    const end = result.indexOf('?=', start + marker.length);
    if (end < 0) {
      return result;
    }
    const decoded = decodeBase64(result.substring(start + marker.length, end));
    result = result.substring(0, start) + decoded + result.substring(end + 2);
    start = result.toUpperCase().indexOf(marker, start + decoded.length);
  }
  return result;
}

export interface SmtpTransport {
  connect(host: string, port: number): Promise<void>;
  send(value: string): Promise<void>;
  readResponse(): Promise<string[]>;
  close(): Promise<void>;
}

function decodeQuotedPrintableBytes(value: string): Uint8Array {
  const source = value.replace(/=\r\n/g, '').replace(/=\n/g, '');
  const bytes = new Uint8Array(source.length * 2);
  let byteIndex = 0;
  for (let index = 0; index < source.length; index++) {
    if (source.charAt(index) === '=' && index + 2 < source.length) {
      const hex = source.substring(index + 1, index + 3);
      if (/^[0-9A-Fa-f]{2}$/.test(hex)) {
        bytes[byteIndex] = Number.parseInt(hex, 16);
        byteIndex++;
        index += 2;
        continue;
      }
    }
    const code = source.charCodeAt(index);
    if (code <= 0xff) {
      bytes[byteIndex] = code;
      byteIndex++;
    } else {
      const encoded = utf8Bytes(source.charAt(index));
      for (let offset = 0; offset < encoded.length; offset++) {
        bytes[byteIndex] = encoded[offset];
        byteIndex++;
      }
    }
  }
  return bytes.slice(0, byteIndex);
}

function decodeBase64(value: string): string {
  const bytes = decodeBase64Bytes(value);
  return decodeUtf8Bytes(bytes, bytes.length);
}

function unfoldedHeaders(value: string): string[] {
  const lines = value.split('\r\n');
  const result: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    if ((lines[index].startsWith(' ') || lines[index].startsWith('\t')) && result.length > 0) {
      result[result.length - 1] += ' ' + lines[index].trim();
    } else {
      result.push(lines[index]);
    }
  }
  return result;
}

function mimeHeader(headers: string, name: string): string {
  const target = name.toLowerCase() + ':';
  const lines = unfoldedHeaders(headers);
  for (let index = 0; index < lines.length; index++) {
    if (lines[index].toLowerCase().startsWith(target)) {
      return decodeMimeWords(lines[index].substring(target.length).trim());
    }
  }
  return '';
}

function addressList(value: string): string[] {
  return value.split(',').map((item: string) => item.trim()).filter((item: string) => item.length > 0);
}

function mimeParameter(contentType: string, name: string): string {
  const parts = contentType.split(';');
  const target = name.toLowerCase();
  for (let index = 1; index < parts.length; index++) {
    const pair = parts[index].split('=');
    if (pair.length >= 2 && pair[0].trim().toLowerCase() === target) {
      let value = pair.slice(1).join('=').trim();
      if (value.length >= 2 && value.charAt(0) === '"' && value.charAt(value.length - 1) === '"') {
        value = value.substring(1, value.length - 1);
      }
      return value;
    }
  }
  return '';
}

function normalizedMimeCharset(value: string): string {
  const charset = value.trim().toLowerCase();
  if (charset.length === 0 || charset === 'us-ascii') {
    return 'utf-8';
  }
  if (charset === 'gb2312' || charset === 'x-gbk') {
    return 'gbk';
  }
  return charset;
}

function decodeMimeBytes(bytes: Uint8Array, charset: string): string {
  const normalized = normalizedMimeCharset(charset);
  try {
    return util.TextDecoder.create(normalized).decodeToString(bytes);
  } catch (_error) {
    aiLogInfo('[AIPhone][QqMailCharsetFallback] charset=' + normalized +
      ' bytes=' + bytes.length.toString());
    return decodeUtf8Bytes(bytes, bytes.length);
  }
}

function decodeTransferBody(body: string, encoding: string, charset: string): string {
  const normalized = encoding.trim().toLowerCase();
  if (normalized === 'base64') {
    return decodeMimeBytes(decodeBase64Bytes(body.replace(/\s/g, '')), charset);
  }
  if (normalized === 'quoted-printable') {
    return decodeMimeBytes(decodeQuotedPrintableBytes(body), charset);
  }
  return body;
}

interface MimeTextParts {
  plain: string;
  html: string;
}

function parseMimeText(raw: string, depth: number = 0): MimeTextParts {
  const split = raw.indexOf('\r\n\r\n');
  if (split < 0) {
    return { plain: raw.trim(), html: '' };
  }
  const headers = raw.substring(0, split);
  const body = raw.substring(split + 4);
  const contentType = mimeHeader(headers, 'Content-Type');
  const mediaType = contentType.split(';')[0].trim().toLowerCase();
  const charset = mimeParameter(contentType, 'charset');
  const transferEncoding = mimeHeader(headers, 'Content-Transfer-Encoding').trim().toLowerCase();
  const boundary = mimeParameter(contentType, 'boundary');
  aiLogInfo('[AIPhone][QqMailMimePart] depth=' + depth.toString() +
    ' type=' + (mediaType.length > 0 ? mediaType : 'text/plain') +
    ' charset=' + (charset.length > 0 ? charset : 'default') +
    ' encoding=' + (transferEncoding.length > 0 ? transferEncoding : 'identity') +
    ' bodyChars=' + body.length.toString());
  if (mediaType.indexOf('multipart/') === 0 && boundary.length > 0) {
    const result: MimeTextParts = { plain: '', html: '' };
    const sections = body.split('--' + boundary);
    aiLogInfo('[AIPhone][QqMailMimeMultipart] depth=' + depth.toString() +
      ' sections=' + Math.max(0, sections.length - 1).toString());
    // sections[0] is the optional multipart preamble, not a MIME body part.
    for (let index = 1; index < sections.length; index++) {
      let section = sections[index];
      if (section.trim().length === 0 || section.trim() === '--') {
        continue;
      }
      if (section.startsWith('\r\n')) {
        section = section.substring(2);
      }
      if (section.endsWith('\r\n')) {
        section = section.substring(0, section.length - 2);
      }
      const parsed = parseMimeText(section, depth + 1);
      if (result.plain.length === 0 && parsed.plain.length > 0) {
        result.plain = parsed.plain;
      }
      if (result.html.length === 0 && parsed.html.length > 0) {
        result.html = parsed.html;
      }
    }
    return result;
  }
  if (mediaType !== 'text/html' && mediaType !== 'text/plain' && mediaType.length > 0) {
    return { plain: '', html: '' };
  }
  const decoded = decodeTransferBody(body, transferEncoding, charset).trim();
  if (mediaType === 'text/html') {
    return { plain: '', html: decoded };
  }
  if (mediaType === 'text/plain' || mediaType.length === 0) {
    return { plain: decoded, html: '' };
  }
  return { plain: '', html: '' };
}

function htmlCodePoint(value: string, radix: number): string {
  const code = Number.parseInt(value, radix);
  if (!Number.isFinite(code) || code < 0 || code > 0x10ffff) {
    return '';
  }
  if (code <= 0xffff) {
    return String.fromCharCode(code);
  }
  const normalized = code - 0x10000;
  return String.fromCharCode(0xd800 + (normalized >> 10)) +
    String.fromCharCode(0xdc00 + (normalized & 0x3ff));
}

function decodeDecimalHtmlEntity(_match: string, value: string): string {
  return htmlCodePoint(value, 10);
}

function decodeHexHtmlEntity(_match: string, value: string): string {
  return htmlCodePoint(value, 16);
}

function decodeHtmlTextEntities(value: string): string {
  return value
    .replace(/&zwnj;|&zwj;|&lrm;|&rlm;|&#8204;|&#8205;/gi, '')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&apos;|&#39;/gi, "'")
    .replace(/&ndash;/gi, '\u2013')
    .replace(/&mdash;/gi, '\u2014')
    .replace(/&hellip;/gi, '\u2026')
    .replace(/&rsquo;/gi, '\u2019')
    .replace(/&lsquo;/gi, '\u2018')
    .replace(/&rdquo;/gi, '\u201d')
    .replace(/&ldquo;/gi, '\u201c')
    .replace(/&#([0-9]+);/g, decodeDecimalHtmlEntity)
    .replace(/&#x([0-9a-f]+);/gi, decodeHexHtmlEntity);
}

function textFromHtml(value: string): string {
  const withoutTags = value
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<\/(p|div|li|tr|h[1-6])\s*>/gi, '\n')
    .replace(/<[^>]+>/g, ' ');
  return decodeHtmlTextEntities(withoutTags)
    .replace(/[\u200b-\u200f\u2060\ufeff]/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/[ \t]*\n[ \t]*/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function rawMessageFromFetch(lines: string[]): string {
  const response = lines.join('\r\n');
  const literal = /\{[0-9]+\}\r\n/.exec(response);
  if (literal === null) {
    return '';
  }
  const start = literal.index + literal[0].length;
  let end = response.lastIndexOf('\r\n)');
  if (end < start) {
    end = response.length;
  }
  return response.substring(start, end);
}

function formatAddress(name: string, mailbox: string, host: string): string {
  const email = mailbox.length > 0 && host.length > 0 ? mailbox + '@' + host : mailbox;
  const display = decodeMimeWords(name).trim();
  if (email.length === 0) {
    return display;
  }
  return display.length > 0 ? display + ' <' + email + '>' : email;
}

function envelopeParts(line: string): string[] {
  const parts: string[] = [];
  let current = '';
  let quoted = false;
  let escaped = false;
  for (let index = 0; index < line.length; index++) {
    const char = line.charAt(index);
    if (escaped) {
      current += char;
      escaped = false;
      continue;
    }
    if (char === '\\' && quoted) {
      escaped = true;
      continue;
    }
    if (char === '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted && (char === '(' || char === ')' || char === ' ')) {
      if (current.length > 0) {
        parts.push(current);
        current = '';
      }
      continue;
    }
    current += char;
  }
  if (current.length > 0) {
    parts.push(current);
  }
  return parts;
}

function isoDate(value: string): string {
  const parts = value.split(' ');
  if (parts.length >= 6) {
    const day = parts[1].length === 1 ? '0' + parts[1] : parts[1];
    const month = monthNumber(parts[2]);
    const year = parts[3];
    const time = parts[4];
    const offset = parts[5];
    if (month.length > 0 && year.length === 4 && time.length >= 8 && offset.length === 5) {
      return year + '-' + month + '-' + day + 'T' + time + '.000' + offset.substring(0, 3) + ':' + offset.substring(3);
    }
  }
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    return '';
  }
  const text = new Date(parsed).toISOString();
  if (text.endsWith('Z')) {
    return text.substring(0, text.length - 1) + '+08:00';
  }
  return text;
}

function monthNumber(value: string): string {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  for (let index = 0; index < months.length; index++) {
    if (months[index] === value) {
      const number = index + 1;
      return number < 10 ? '0' + number.toString() : number.toString();
    }
  }
  return '';
}

function lastMessageId(parts: string[], fallback: string): string {
  for (let index = parts.length - 1; index >= 0; index--) {
    const value = parts[index];
    if (value.indexOf('@') >= 0 || value.indexOf('<') >= 0) {
      return value;
    }
  }
  return fallback;
}

export function parseImapEnvelopeList(lines: string[], accountLabel: string): MailThreadResult[] {
  const results: MailThreadResult[] = [];
  lines.forEach((line: string) => {
    const uidMatch = line.match(/UID ([0-9]+)/);
    if (uidMatch === null) {
      return;
    }
    const envelopeIndex = line.indexOf('ENVELOPE');
    if (envelopeIndex < 0) {
      return;
    }
    const parts = envelopeParts(line.substring(envelopeIndex));
    const date = parts.length > 1 ? parts[1] : '';
    const subject = parts.length > 2 ? decodeMimeWords(parts[2]) : '(no subject)';
    const fromName = parts.length > 3 && parts[3] !== 'NIL' ? parts[3] : '';
    const fromMailbox = parts.length > 5 && parts[5] !== 'NIL' ? parts[5] : '';
    const fromHost = parts.length > 6 && parts[6] !== 'NIL' ? parts[6] : '';
    const providerMessageId = lastMessageId(parts, uidMatch[1]);
    results.push({
      provider: 'qq',
      accountLabel: accountLabel,
      threadId: '',
      messageId: uidMatch[1],
      subject: subject,
      from: formatAddress(fromName, fromMailbox, fromHost),
      to: [],
      participants: [],
      snippet: '',
      receivedAt: isoDate(date),
      unread: line.indexOf('\\\\Seen') < 0,
      important: line.indexOf('\\\\Flagged') >= 0,
      sourceUrl: '',
      rawProviderRef: providerMessageId
    });
  });
  return results;
}

export function pickDraftMailbox(mailboxes: string[], configured: string): string {
  if (configured.trim().length > 0) {
    return configured.trim();
  }
  const candidates = ['Drafts', '草稿箱', '&g0l6P3ux-'];
  for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
    for (let index = 0; index < mailboxes.length; index++) {
      if (mailboxes[index] === candidates[candidateIndex]) {
        return mailboxes[index];
      }
    }
  }
  return 'Drafts';
}

function encodeHeader(value: string): string {
  let ascii = true;
  for (let index = 0; index < value.length; index++) {
    if (value.charCodeAt(index) > 127) {
      ascii = false;
      break;
    }
  }
  return ascii ? value : '=?UTF-8?B?' + bytesToBase64(utf8Bytes(value)) + '?=';
}

export function buildQqDraftMime(args: MailDraftArgs, fromAddress: string): string {
  const headers: string[] = [
    'From: ' + fromAddress,
    'To: ' + args.to.join(', '),
    'Subject: ' + encodeHeader(args.subject),
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8'
  ];
  const referenceId = mailReferenceId(args);
  if (referenceId.length > 0) {
    headers.push('In-Reply-To: ' + referenceId);
    headers.push('References: ' + referenceId);
  }
  return headers.join('\r\n') + '\r\n\r\n' + args.body + '\r\n';
}

function mailReferenceId(args: MailDraftArgs): string {
  const explicit = args.internetMessageId === undefined ? '' : args.internetMessageId.trim();
  if (explicit.length > 0) {
    return explicit;
  }
  const fallback = args.messageId.trim();
  return fallback.indexOf('@') >= 0 || fallback.startsWith('<') ? fallback : '';
}

function wrappedBase64(value: string): string {
  const encoded = bytesToBase64(utf8Bytes(value));
  const lines: string[] = [];
  for (let index = 0; index < encoded.length; index += 76) {
    lines.push(encoded.substring(index, Math.min(encoded.length, index + 76)));
  }
  return lines.join('\r\n');
}

export function buildQqReplyMime(args: MailDraftArgs, fromAddress: string): string {
  const headers: string[] = [
    'From: ' + fromAddress,
    'To: ' + args.to.join(', '),
    'Subject: ' + encodeHeader(args.subject),
    'Date: ' + new Date().toUTCString(),
    'Message-ID: <appless-' + Date.now().toString() + '@qq.com>',
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64'
  ];
  const referenceId = mailReferenceId(args);
  if (referenceId.length > 0) {
    headers.push('In-Reply-To: ' + referenceId);
    headers.push('References: ' + referenceId);
  }
  return headers.join('\r\n') + '\r\n\r\n' + wrappedBase64(args.body) + '\r\n';
}

function smtpAddress(value: string): string {
  const trimmed = value.trim();
  const left = trimmed.lastIndexOf('<');
  const right = trimmed.lastIndexOf('>');
  if (left >= 0 && right > left) {
    return trimmed.substring(left + 1, right).trim();
  }
  return trimmed;
}

function smtpResponseCode(lines: string[]): string {
  for (let index = lines.length - 1; index >= 0; index--) {
    const line = lines[index].trim();
    if (/^[0-9]{3} /.test(line)) {
      return line.substring(0, 3);
    }
  }
  return '';
}

function requireSmtpCode(lines: string[], allowed: string[], stage: string): void {
  const code = smtpResponseCode(lines);
  if (allowed.indexOf(code) < 0) {
    throw new Error('QQ SMTP ' + stage + ' rejected with code ' + (code.length > 0 ? code : 'unknown') + '.');
  }
}

function smtpDotStuffed(value: string): string {
  return value.split('\r\n').map((line: string) => line.startsWith('.') ? '.' + line : line).join('\r\n');
}

function redactedAccountLabel(address: string): string {
  const at = address.indexOf('@');
  if (address.length === 0 || at <= 0) {
    return 'qq';
  }
  return address.substring(0, 1) + '***' + address.substring(at);
}

function selectedUidSet(lines: string[], pageSize: number): string {
  const ids: string[] = [];
  lines.forEach((line: string) => {
    if (line.indexOf('* SEARCH') < 0) {
      return;
    }
    const pieces = line.replace('* SEARCH', '').split(' ');
    pieces.forEach((piece: string) => {
      const value = piece.trim();
      if (/^[0-9]+$/.test(value)) {
        ids.push(value);
      }
    });
  });
  const size = Math.max(1, pageSize);
  return ids.slice(Math.max(0, ids.length - size)).join(',');
}

function imapQuoted(value: string): string {
  return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function imapKeywordTerms(query: string): string[] {
  const quoted: string[] = [];
  const quoteRegex = /"([^"]+)"/g;
  let match = quoteRegex.exec(query);
  while (match !== null) {
    if (match[1].trim().length > 0) {
      quoted.push(match[1].trim());
    }
    match = quoteRegex.exec(query);
  }
  const rawTerms = quoted.length > 0 ? quoted : query.split(/\s+/);
  const terms: string[] = [];
  rawTerms.forEach((term: string) => {
    const cleaned = term.replace(/[{}()]/g, '').trim();
    if (cleaned.length === 0 ||
      cleaned.indexOf(':') >= 0 ||
      cleaned.charAt(0) === '-' ||
      cleaned.toUpperCase() === 'OR') {
      return;
    }
    terms.push(cleaned);
  });
  return terms.slice(0, 3);
}

function imapSearchCriteria(query: string): string {
  const keys: string[] = [];
  const match = /newer_than:([0-9]+)d/i.exec(query);
  if (match !== null) {
    const days = Number.parseInt(match[1], 10);
    if (!Number.isNaN(days) && days > 0) {
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      keys.push('SINCE ' + since.getDate().toString() + '-' + months[since.getMonth()] + '-' + since.getFullYear().toString());
    }
  }
  imapKeywordTerms(query).forEach((term: string) => {
    keys.push('TEXT ' + imapQuoted(term));
  });
  return keys.length > 0 ? keys.join(' ') : 'ALL';
}

function visibleMatchesTerms(thread: MailThreadResult, terms: string[]): boolean {
  if (terms.length === 0) {
    return true;
  }
  const text = (thread.subject + ' ' + thread.snippet + ' ' + thread.from).toLowerCase();
  for (let index = 0; index < terms.length; index++) {
    if (text.indexOf(terms[index].toLowerCase()) >= 0) {
      return true;
    }
  }
  return false;
}

const DIGICERT_GLOBAL_ROOT_G2_CA = '-----BEGIN CERTIFICATE-----\n' +
  'MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBh\n' +
  'MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\n' +
  'd3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBH\n' +
  'MjAeFw0xMzA4MDExMjAwMDBaFw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVT\n' +
  'MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j\n' +
  'b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IEcyMIIBIjANBgkqhkiG\n' +
  '9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/RrohCgiN9RlUyfuI\n' +
  '2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxpsMNzaHxmx\n' +
  '1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ\n' +
  'q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5Wz\n' +
  'tCO7TG1F8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQ\n' +
  'vIOlCsRnKPZzFBQ9RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAP\n' +
  'BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV\n' +
  '5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcNAQELBQADggEBAGBnKJRvDkhj6zHd6mcY\n' +
  '1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVnNeyIv/iPsGEMNKSuIEyExtv4\n' +
  'NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2ZL7tcu7XUIOGZX1NG\n' +
  'Fdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUTFy8bJZ91\n' +
  '8rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe\n' +
  'pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTfl\n' +
  'MrY=\n' +
  '-----END CERTIFICATE-----';
const IMAP_READ_TIMEOUT_MS = 20000;

function imapCommandSummary(line: string): string {
  const parts = line.trim().split(' ');
  if (parts.length >= 2) {
    return parts[0] + ' ' + parts[1];
  }
  return parts.length === 1 ? parts[0] : 'unknown';
}

export class TlsImapTransport implements ImapTransport {
  private tcpSocket: socket.TCPSocket | null = null;
  private tlsSocket: socket.TLSSocket | null = null;
  private buffer: string = '';
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  async connect(host: string, port: number): Promise<void> {
    aiLogInfo('[AIPhone][QqMailImapConnectStart] host=' + host + ' port=' + port.toString());
    this.tcpSocket = socket.constructTCPSocketInstance();
    await this.tcpSocket.bind({ address: '0.0.0.0', port: 0 });
    await this.tcpSocket.connect({
      address: { address: host, port: port },
      timeout: 15000
    });
    this.tlsSocket = socket.constructTLSSocketInstance(this.tcpSocket);
    this.tlsSocket.on('message', (value: socket.SocketMessageInfo) => {
      this.buffer += this.decoder.decodeToString(new Uint8Array(value.message), { stream: true });
    });
    await this.tlsSocket.connect({
      address: { address: host, port: port },
      secureOptions: { ca: [DIGICERT_GLOBAL_ROOT_G2_CA] },
      timeout: 15000
    });
    aiLogInfo('[AIPhone][QqMailImapConnectOk] host=' + host + ' port=' + port.toString());
  }

  async send(line: string): Promise<void> {
    if (this.tlsSocket === null) {
      throw new Error('IMAP socket is not connected.');
    }
    aiLogInfo('[AIPhone][QqMailImapSend] command=' + imapCommandSummary(line));
    const payload = utf8Bytes(line + '\r\n');
    await this.tlsSocket.send(payload.buffer.slice(payload.byteOffset, payload.byteOffset + payload.byteLength));
  }

  async readUntil(tag: string): Promise<string[]> {
    const started = Date.now();
    aiLogInfo('[AIPhone][QqMailImapReadStart] tag=' + tag);
    while (this.buffer.indexOf(tag + ' OK') < 0 && this.buffer.indexOf(tag + ' NO') < 0 && this.buffer.indexOf(tag + ' BAD') < 0) {
      if (Date.now() - started > IMAP_READ_TIMEOUT_MS) {
        aiLogInfo('[AIPhone][QqMailImapReadTimeout] tag=' + tag +
          ' bufferedChars=' + this.buffer.length.toString());
        throw new Error('QQ IMAP timeout waiting for ' + tag + ' buffered=' + this.buffer.substring(0, 120));
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    const text = this.buffer;
    this.buffer = '';
    // MIME uses empty lines to separate each part's headers from its body.
    // Keep them intact; search/envelope parsers already ignore unrelated lines.
    const lines = text.split('\r\n');
    aiLogInfo('[AIPhone][QqMailImapReadDone] tag=' + tag +
      ' lines=' + lines.length.toString() +
      ' chars=' + text.length.toString());
    return lines;
  }

  async close(): Promise<void> {
    if (this.tlsSocket !== null) {
      await this.tlsSocket.close();
      this.tlsSocket = null;
      this.tcpSocket = null;
    } else if (this.tcpSocket !== null) {
      await this.tcpSocket.close();
      this.tcpSocket = null;
    }
  }
}

const SMTP_READ_TIMEOUT_MS = 20000;

export class TlsSmtpTransport implements SmtpTransport {
  private tcpSocket: socket.TCPSocket | null = null;
  private tlsSocket: socket.TLSSocket | null = null;
  private buffer: string = '';
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  async connect(host: string, port: number): Promise<void> {
    aiLogInfo('[AIPhone][QqMailSmtpConnectStart] host=' + host + ' port=' + port.toString());
    this.tcpSocket = socket.constructTCPSocketInstance();
    await this.tcpSocket.bind({ address: '0.0.0.0', port: 0 });
    await this.tcpSocket.connect({
      address: { address: host, port: port },
      timeout: 15000
    });
    this.tlsSocket = socket.constructTLSSocketInstance(this.tcpSocket);
    this.tlsSocket.on('message', (value: socket.SocketMessageInfo) => {
      this.buffer += this.decoder.decodeToString(new Uint8Array(value.message), { stream: true });
    });
    await this.tlsSocket.connect({
      address: { address: host, port: port },
      secureOptions: { ca: [DIGICERT_GLOBAL_ROOT_G2_CA] },
      timeout: 15000
    });
    aiLogInfo('[AIPhone][QqMailSmtpConnectOk] host=' + host + ' port=' + port.toString());
  }

  async send(value: string): Promise<void> {
    if (this.tlsSocket === null) {
      throw new Error('SMTP socket is not connected.');
    }
    aiLogInfo('[AIPhone][QqMailSmtpSend] chars=' + value.length.toString());
    const payload = utf8Bytes(value + '\r\n');
    await this.tlsSocket.send(payload.buffer.slice(payload.byteOffset, payload.byteOffset + payload.byteLength));
  }

  async readResponse(): Promise<string[]> {
    const started = Date.now();
    while (!/(^|\r\n)[0-9]{3} [^\r\n]*\r\n/.test(this.buffer)) {
      if (Date.now() - started > SMTP_READ_TIMEOUT_MS) {
        throw new Error('QQ SMTP timeout waiting for response.');
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    const text = this.buffer;
    this.buffer = '';
    const lines = text.split('\r\n').filter((line: string) => line.length > 0);
    aiLogInfo('[AIPhone][QqMailSmtpRead] code=' + smtpResponseCode(lines) +
      ' lines=' + lines.length.toString());
    return lines;
  }

  async close(): Promise<void> {
    if (this.tlsSocket !== null) {
      await this.tlsSocket.close();
      this.tlsSocket = null;
      this.tcpSocket = null;
    } else if (this.tcpSocket !== null) {
      await this.tcpSocket.close();
      this.tcpSocket = null;
    }
  }
}

export class QqMailImapClient {
  private config: QqMailConfig;
  private transportFactory: () => ImapTransport;
  private smtpTransportFactory: () => SmtpTransport;

  constructor(
    config: QqMailConfig,
    transportFactory: (() => ImapTransport) | null = null,
    smtpTransportFactory: (() => SmtpTransport) | null = null
  ) {
    this.config = config;
    this.transportFactory = transportFactory === null ? (() => new TlsImapTransport()) : transportFactory;
    this.smtpTransportFactory = smtpTransportFactory === null ? (() => new TlsSmtpTransport()) : smtpTransportFactory;
  }

  private async withTransport<T>(operation: (transport: ImapTransport) => Promise<T>): Promise<T> {
    const transport = this.transportFactory();
    try {
      await transport.connect(this.config.imapHost, this.config.imapPort);
      await transport.readUntil('*');
      return await operation(transport);
    } finally {
      await transport.close();
    }
  }

  async search(args: MailSearchArgs): Promise<MailThreadResult[]> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    return this.withTransport(async (transport: ImapTransport) => {
      await transport.send('a1 LOGIN "' + this.config.address + '" "' + this.config.authCode + '"');
      const login = await transport.readUntil('a1');
      if (login.join('\n').indexOf('a1 OK') < 0) {
        throw new Error('QQ IMAP login rejected.');
      }
      await transport.send('a2 SELECT INBOX');
      await transport.readUntil('a2');
      await transport.send('a3 UID SEARCH ' + imapSearchCriteria(args.query));
      const searchLines = await transport.readUntil('a3');
      const selected = selectedUidSet(searchLines, args.pageSize);
      if (selected.length === 0) {
        return [];
      }
      await transport.send('a4 UID FETCH ' + selected + ' (UID FLAGS ENVELOPE)');
      const fetchLines = await transport.readUntil('a4');
      const terms = imapKeywordTerms(args.query);
      return parseImapEnvelopeList(fetchLines, redactedAccountLabel(this.config.address))
        .filter((thread: MailThreadResult) => visibleMatchesTerms(thread, terms));
    });
  }

  async readDetail(args: MailDetailRequest): Promise<MailDetail> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    if (!/^[0-9]+$/.test(args.messageId.trim())) {
      throw new Error('QQ Mail detail requires a numeric IMAP UID.');
    }
    return this.withTransport(async (transport: ImapTransport) => {
      await transport.send('a1 LOGIN "' + this.config.address + '" "' + this.config.authCode + '"');
      const login = await transport.readUntil('a1');
      if (login.join('\n').indexOf('a1 OK') < 0) {
        throw new Error('QQ IMAP login rejected.');
      }
      await transport.send('a2 SELECT INBOX');
      await transport.readUntil('a2');
      await transport.send('a3 UID FETCH ' + args.messageId.trim() + ' (BODY.PEEK[])');
      const fetchLines = await transport.readUntil('a3');
      const raw = rawMessageFromFetch(fetchLines);
      if (raw.length === 0) {
        throw new Error('QQ IMAP returned no message body.');
      }
      const headerEnd = raw.indexOf('\r\n\r\n');
      const headers = headerEnd >= 0 ? raw.substring(0, headerEnd) : raw;
      const mime = parseMimeText(raw);
      const bodyText = (mime.plain.length > 0 ? mime.plain : textFromHtml(mime.html)).substring(0, 30000);
      const detail: MailDetail = {
        requestKey: args.requestKey,
        provider: 'qq',
        threadId: args.threadId,
        messageId: args.messageId,
        internetMessageId: mimeHeader(headers, 'Message-ID'),
        subject: mimeHeader(headers, 'Subject').length > 0 ? mimeHeader(headers, 'Subject') : args.subject,
        from: mimeHeader(headers, 'From'),
        replyTo: mimeHeader(headers, 'Reply-To'),
        to: addressList(mimeHeader(headers, 'To')),
        cc: addressList(mimeHeader(headers, 'Cc')),
        bodyText: bodyText,
        bodyHtml: mime.html.substring(0, 30000)
      };
      return detail;
    });
  }

  async createDraft(args: MailDraftArgs): Promise<DynamicGenericToolResult> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    return this.withTransport(async (transport: ImapTransport) => {
      await transport.send('a1 LOGIN "' + this.config.address + '" "' + this.config.authCode + '"');
      const login = await transport.readUntil('a1');
      if (login.join('\n').indexOf('a1 OK') < 0) {
        throw new Error('QQ IMAP login rejected.');
      }
      await transport.send('a2 LIST "" "*"');
      const listLines = await transport.readUntil('a2');
      const mailboxes: string[] = [];
      listLines.forEach((line: string) => {
        const quote = line.lastIndexOf('"');
        const previous = line.lastIndexOf('"', quote - 1);
        if (previous >= 0 && quote > previous) {
          mailboxes.push(line.substring(previous + 1, quote));
        }
      });
      const mailbox = pickDraftMailbox(mailboxes, this.config.draftsMailbox);
      const mime = buildQqDraftMime(args, this.config.address);
      await transport.send('a3 APPEND "' + mailbox + '" (\\Draft) {' + utf8Bytes(mime).length.toString() + '}');
      await transport.send(mime);
      const append = await transport.readUntil('a3');
      if (append.join('\n').indexOf('a3 OK') < 0) {
        throw new Error('QQ IMAP draft append rejected.');
      }
      aiLogInfo('[AIPhone][QqMailDraftSaved] mailbox=' + mailbox + ' bodyChars=' + args.body.length.toString());
      const rows: A2uiLabelValueData[] = [
        { label: 'Source', value: 'QQ Mail' },
        { label: 'Mailbox', value: mailbox },
        { label: 'To', value: args.to.join(', ') },
        { label: 'Subject', value: args.subject },
        { label: 'Status', value: 'Saved draft, not sent' }
      ];
      const result: DynamicGenericToolResult = {
        sourceTag: 'QQ Mail',
        toolName: 'mail.draft.create',
        title: 'QQ 邮箱草稿已保存',
        status: 'success',
        summary: '已保存到真实 QQ 邮箱草稿箱；尚未发送。',
        rows: rows,
        rawPreview: 'qq draft saved mailbox=' + mailbox
      };
      return result;
    });
  }

  async sendReply(args: MailDraftArgs): Promise<DynamicGenericToolResult> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    if (args.to.length === 0 || args.body.trim().length === 0) {
      throw new Error('QQ Mail reply requires a recipient and body.');
    }
    const transport = this.smtpTransportFactory();
    try {
      await transport.connect('smtp.qq.com', 465);
      requireSmtpCode(await transport.readResponse(), ['220'], 'greeting');
      await transport.send('EHLO appless-phone.local');
      requireSmtpCode(await transport.readResponse(), ['250'], 'EHLO');
      await transport.send('AUTH LOGIN');
      requireSmtpCode(await transport.readResponse(), ['334'], 'AUTH LOGIN');
      await transport.send(bytesToBase64(utf8Bytes(this.config.address)));
      requireSmtpCode(await transport.readResponse(), ['334'], 'username');
      await transport.send(bytesToBase64(utf8Bytes(this.config.authCode)));
      requireSmtpCode(await transport.readResponse(), ['235'], 'authentication');
      await transport.send('MAIL FROM:<' + this.config.address + '>');
      requireSmtpCode(await transport.readResponse(), ['250'], 'MAIL FROM');
      for (let index = 0; index < args.to.length; index++) {
        await transport.send('RCPT TO:<' + smtpAddress(args.to[index]) + '>');
        requireSmtpCode(await transport.readResponse(), ['250', '251'], 'RCPT TO');
      }
      await transport.send('DATA');
      requireSmtpCode(await transport.readResponse(), ['354'], 'DATA');
      const mime = buildQqReplyMime(args, this.config.address);
      await transport.send(smtpDotStuffed(mime) + '\r\n.');
      requireSmtpCode(await transport.readResponse(), ['250'], 'message body');
      await transport.send('QUIT');
      aiLogInfo('[AIPhone][QqMailReplySent] recipients=' + args.to.length.toString() +
        ' bodyChars=' + args.body.length.toString());
      const rows: A2uiLabelValueData[] = [
        { label: 'Source', value: 'QQ Mail SMTP' },
        { label: 'To', value: args.to.join(', ') },
        { label: 'Subject', value: args.subject },
        { label: 'Status', value: 'Sent' }
      ];
      const result: DynamicGenericToolResult = {
        sourceTag: 'QQ Mail',
        toolName: 'mail.reply.send',
        title: 'QQ 邮箱回复已发送',
        status: 'success',
        summary: '已通过 QQ SMTP 发送回复。',
        rows: rows,
        rawPreview: 'qq reply sent recipients=' + args.to.length.toString()
      };
      return result;
    } finally {
      await transport.close();
    }
  }
}
