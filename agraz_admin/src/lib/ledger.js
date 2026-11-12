function asNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function round2(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

function dateKey(row) {
  return String(row.date || row.transaction_date || row.created_at || '');
}

function byDateAsc(a, b) {
  const cmp = dateKey(a).localeCompare(dateKey(b));
  if (cmp) return cmp;
  return (Number(a.id) || 0) - (Number(b.id) || 0);
}

function ieType(row) {
  return String(row.type || row.receipt_payment_type || '').toLowerCase();
}

/** One book: income and expense side by side, balance after each row. */
export function incomeExpenseLedger(rows) {
  const ordered = [...(rows || [])].sort(byDateAsc);
  const byId = new Map();
  let balance = 0;
  let income = 0;
  let expense = 0;
  for (const row of ordered) {
    const amount = round2(Math.abs(asNumber(row.amount)));
    const type = ieType(row);
    let incomeAmt = null;
    let expenseAmt = null;
    if (type === 'income') {
      incomeAmt = amount;
      income += amount;
      balance = round2(balance + amount);
    } else if (type === 'expense') {
      expenseAmt = amount;
      expense += amount;
      balance = round2(balance - amount);
    }
    byId.set(row.id, { income: incomeAmt, expense: expenseAmt, balance });
  }
  return {
    byId,
    income: round2(income),
    expense: round2(expense),
    balance: round2(income - expense),
  };
}

function labourKind(row) {
  const kind = String(row.entry_kind || 'payable').toLowerCase();
  return kind || 'payable';
}

/** Rate is wage. Qty is days/hours, times the number of labours when that is more than one. */
export function labourRateQty(row) {
  const rate = round2(asNumber(row.wage));
  const days = asNumber(row.hours);
  const people = Math.max(1, Math.round(asNumber(row.number_of_labours)) || 1);
  const dayQty = days > 0 ? days : 1;
  const qty = round2(dayQty * people);
  return { rate, days: round2(dayQty), people, qty };
}

function labourExtras(row) {
  const extra = row.extra || {};
  return asNumber(extra.rent) + asNumber(extra.food) + asNumber(extra.bonus);
}

/**
 * One labour book, in date order.
 * Payable adds to the balance, payment subtracts.
 * An opening row replaces the balance. A tally row sets it back to zero.
 */
export function labourLedger(rows) {
  const byId = new Map();
  let payable = 0;
  let payment = 0;
  let running = 0;
  for (const row of [...(rows || [])].sort(byDateAsc)) {
      const kind = labourKind(row);
      const parts = labourRateQty(row);
      let payableAmt = null;
      let paymentAmt = null;
      let amount = null;
      let rate = null;
      let qty = null;
      if (kind === 'tally') {
        running = 0;
      } else if (kind === 'payment') {
        // A payment is a lump sum. Hours is 1, so this stays the amount paid.
        amount = round2(Math.abs(parts.rate * parts.days));
        paymentAmt = amount;
        payment += paymentAmt;
        running = round2(running - paymentAmt);
      } else if (kind === 'opening') {
        const signed = round2(parts.rate * parts.days);
        amount = round2(Math.abs(signed));
        rate = parts.rate;
        qty = parts.days;
        if (signed >= 0) {
          payableAmt = amount;
          payable += payableAmt;
        } else {
          paymentAmt = amount;
          payment += paymentAmt;
        }
        running = signed;
      } else {
        // Payable work: amount = rate × qty (+ rent, food, bonus).
        rate = parts.rate;
        qty = parts.qty;
        amount = round2(Math.abs(parts.rate) * parts.qty + labourExtras(row));
        payableAmt = amount;
        payable += payableAmt;
        running = round2(running + payableAmt);
      }
      byId.set(row.id, {
        rate,
        qty,
        people: parts.people,
        days: parts.days,
        amount,
        payable: payableAmt,
        payment: paymentAmt,
        balance: running,
      });
    }
  return {
    byId,
    payable: round2(payable),
    payment: round2(payment),
    balance: running,
  };
}

export function blankMoney(value) {
  return value == null ? '' : value;
}
