// Учебные данные. Коллекцию заполняем, только если она пустая,
// поэтому повторный запуск ничего не портит.
// Значения считаются из номера документа: данные одинаковые при каждом запуске.

function fill(dbName, coll, n, make) {
  const c = db.getSiblingDB(dbName)[coll];
  if (c.estimatedDocumentCount() > 0) {
    print(`${dbName}.${coll}: exists, ${c.countDocuments()} docs`);
    return;
  }
  const docs = [];
  for (let i = 1; i <= n; i++) docs.push(make(i));
  c.insertMany(docs);
  print(`${dbName}.${coll}: created, ${n} docs`);
}

const cities = ['Saint Petersburg', 'Moscow', 'Kazan', 'Novosibirsk', 'Perm'];
const statuses = ['new', 'paid', 'shipped', 'delivered', 'cancelled'];

fill('shop', 'products', 200, i => ({
  _id: i, name: `product-${i}`, category: `cat-${i % 10}`, price: 100 + (i * 37) % 900,
}));
fill('shop', 'customers', 1000, i => ({
  _id: i, name: `customer-${i}`, email: `c${i}@example.com`, city: cities[i % cities.length],
}));
fill('shop', 'orders', 20000, i => ({
  _id: i, customerId: 1 + (i * 7) % 1000, status: statuses[i % statuses.length],
  items: [{ productId: 1 + i % 200, qty: 1 + i % 3 }, { productId: 1 + (i * 3) % 200, qty: 1 }],
  total: 100 + (i * 13) % 5000, createdAt: new Date(Date.UTC(2026, 0, 1) + i * 60000),
}));
db.getSiblingDB('shop').orders.createIndex({ customerId: 1 });

fill('school', 'courses', 12, i => ({ _id: i, title: `course-${i}`, credits: 2 + i % 4 }));
fill('school', 'students', 300, i => ({
  _id: i, name: `student-${i}`, group: `M41${i % 5}`, courses: [1 + i % 12, 1 + (i + 5) % 12],
}));
