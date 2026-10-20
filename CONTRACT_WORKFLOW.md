# Contract Manage — Clean Workflow

End-to-end civil contractor flow in AgRaz (app + admin).  
Masters alone are not enough — **always work from a Project**.

---

## Recommended daily path

```
1. Customer          → who owns the site
2. Project           → map customer + start/end + status + contract amount
3. Open Project      → Project Workspace (source of truth)
4. Send labour       → men / women / rates / days / paid / extra
5. Money             → customer advance · receipts · pay lead · pay dealer · commission
6. Stock             → buy (own yard or customer site) · issue / use on site
7. Overview tab      → answers balances anytime
```

---

## Masters (set up once)

| Menu | Purpose |
|------|---------|
| **Customers** | Site owner / client (name, mobile, village) |
| **Labour Suppliers** | Labour leads who supply gangs |
| **Labours** | Workers under each lead (optional detail) |
| **Dealers** | Sand / cement / material suppliers |
| **Materials** | Stock master (unit: bag, ton, cft…) |
| **Assets** | JCB, mixer, etc. + purchase details |

Create these before or while running the first project.

---

## Transactions (the real work)

### 1. Create Project (required)
- Menu: **Projects → New project**
- Fields: name, **customer** (required), **status** (planned / active / on_hold / completed / cancelled), **start date**, **end date**, contract amount, location
- Actions: **Edit**, **Delete**, open ledger

### 2. Open Project Workspace
Tap / open the project. Tabs:

| Tab | What you do | Questions it answers |
|-----|-------------|----------------------|
| **Overview** | Read totals | How much advance? Open receivable? Men/women days? Labour balance? Dealer paid? Extra to lead? |
| **Labour** | **Send labour** | How many men/women, rates, days worked, paid to lead, extra |
| **Payments** | Advances & pays | Customer advance / receipt; pay labour lead; extra; pay dealer; commission |
| **Stock** | Buy & issue | Where stock was bought (own / customer site); quantity used on site |
| **Audit** | History | Who created/updated/deleted what |

### 3. Labour Work (also in sidebar)
Same labour deployment list across all projects.  
Still prefer **Project → Labour** so totals stay tied to one job.

### 4. Stock Issues (sidebar)
Use / transfer stock without opening the project first.  
Prefer **Project → Stock** for job context.

---

## Money kinds (Payments)

| Kind | Meaning |
|------|---------|
| `customer_advance` | Advance received from customer (often before / during work) |
| `customer_receipt` | Progress / final payment from customer |
| `labour_payment` | Amount paid to labour lead / supplier |
| `labour_extra` | Extra paid to labour / lead |
| `dealer_payment` | Amount paid to material dealer |
| `commission` | Contractor commission from customer |

Unpaid material purchases can auto-create a **dealer payable**.

---

## Stock locations

| Location | Meaning |
|----------|---------|
| **own** | Contractor’s yard |
| **customer** | Material kept at customer / site |

**Issue purposes:** `site_use` · `transfer_to_customer` · `return_to_own`

---

## How to get answers (cheat sheet)

| Question | Where |
|----------|--------|
| How many labour / men / women / days / rates? | Project → Labour + Overview |
| How much paid to lead? Extra? | Labour row + Payments (`labour_payment` / `labour_extra`) + Overview |
| Advance from customer? Future due? | Payments → Customer advance (optional due date) |
| How much still receivable on contract? | Overview → Open receivable |
| Where was stock bought? | Project → Stock → Purchases |
| Stock at customer vs own yard? | Stock Report |
| Full history of changes? | Audit Log |

---

## Admin URLs

Base: `https://agrazllp.com/agraz_admin/`

- Hub: `/contract-manage`
- Projects: `/contract-manage/projects`
- Project ledger: `/contract-manage/projects/:id`
- Labour Work: `/contract-manage/labour-works`
- Stock Issues: `/contract-manage/stock-issues`
- Audit: `/contract-manage/audit`

---

## App (Flutter)

Drawer → **CONTRACT → Contract Manage**

1. Hub explains the start path  
2. **Projects** → create with customer / dates / status  
3. Tap project → same workspace tabs as admin  

Existing farm menus are unchanged.

---

## Do / Don’t

**Do**
- Map every project to a customer  
- Enter labour against a project  
- Record advances and lead payments on that project  
- Use Overview before paying or closing a job  

**Don’t**
- Enter labour/money with no project (totals won’t reconcile)  
- Expect masters alone to show site progress  
- Confuse farm **Labour Work Entry** (agriculture module) with Contract **Labour Work**

---

## Status values (Project)

`planned` → `active` → `on_hold` (optional) → `completed` · or `cancelled`
