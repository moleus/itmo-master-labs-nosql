// Нагрузка на учебную базу shop. Один процесс mongosh = один поток.
// Длительность в секундах: переменная окружения LOAD_SECONDS.
// Смесь операций:
//   insert пачками в shop.events      -> растут opcounters insert, кэш, журнал
//     (events -- capped-коллекция 1 ГБ: старые документы удаляются, диск не забивается)
//   find по индексу customerId        -> быстрые чтения, scanned ~= returned
//   find по полю без индекса (total)  -> COLLSCAN: scanned >> returned
//   update статуса заказа             -> opcounters update, грязные страницы в кэше
const seconds = Number(process.env.LOAD_SECONDS || 120);
const shop = db.getSiblingDB('shop');
const end = Date.now() + seconds * 1000;
const pad = 'x'.repeat(200);
let n = 0;
while (Date.now() < end) {
  const batch = [];
  for (let i = 0; i < 100; i++) batch.push({ at: new Date(), worker: process.pid, n: n++, pad });
  shop.events.insertMany(batch, { ordered: false });
  shop.orders.find({ customerId: 1 + n % 1000 }).toArray();
  if (n % 1000 === 0) shop.orders.find({ total: n % 5000 }).toArray();
  shop.orders.updateOne({ _id: 1 + n % 20000 }, { $set: { status: 'paid' } });
}
print(`worker ${process.pid}: ${n} events inserted`);
