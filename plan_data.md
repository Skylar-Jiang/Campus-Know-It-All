# 校园活动报名与共享物资调配管理系统  
## 实现文档 v1.0

---

## 一、项目目标与范围

### 1.1 项目名称
**校园活动报名与共享物资调配管理系统**

### 1.2 项目目标
实现一个面向校园活动管理的小型信息管理系统，支持：

- 社团发布活动
- 学生查看并报名活动
- 活动签到
- 活动物资借用与归还
- 统计活动报名和物资使用情况

本系统设计重点不是页面炫酷，而是保证数据库部分完整，特别是以下四类操作能够自然落地：

- 含事务的删除
- 触发器控制下的添加
- 存储过程控制下的更新
- 基于视图的查询

### 1.3 项目范围控制
为了确保项目可实现，系统范围只保留以下 5 个核心模块：

1. 用户与角色管理
2. 活动管理
3. 活动报名与签到
4. 共享物资借用与归还
5. 活动综合统计查询

### 1.4 不纳入本次实现的功能
以下功能会显著增加工作量，但对数据库课程作业得分帮助有限，因此不纳入本次实现：

- 支付功能
- 消息聊天
- 文件上传
- 推荐算法
- 地图导航
- 复杂审批流
- 复杂权限系统

---

## 二、推荐技术方案

### 2.1 技术栈

#### 前端
- HTML
- CSS
- Bootstrap
- Jinja2 模板

#### 后端
- Python
- Flask

#### 数据库
- MySQL 8.0

#### 数据库连接
- PyMySQL 或 SQLAlchemy

### 2.2 选择理由
本项目重点在数据库课程要求，因此采用 Flask + MySQL 方案，原因如下：

- 环境搭建快
- 路由清晰
- SQL 易于控制
- 调用触发器、存储过程、视图方便
- 页面数量适中，适合作业开发

---

## 三、系统角色设计

系统共设置 3 类角色。

### 3.1 管理员
负责：

- 管理活动
- 删除活动
- 查看统计
- 处理活动结算

### 3.2 社团负责人
负责：

- 发布活动
- 修改活动
- 申请借用物资
- 归还物资
- 活动签到

### 3.3 学生
负责：

- 查看活动
- 报名活动
- 查看自己的报名情况

---

## 四、核心业务流程

### 4.1 活动业务流程
社团负责人创建活动  
→ 发布活动  
→ 学生报名  
→ 活动开始后签到  
→ 活动结束  
→ 系统结算活动状态和学生积分

### 4.2 物资业务流程
社团负责人为某活动发起借用申请  
→ 添加借用明细  
→ 系统检查库存是否足够  
→ 活动结束后归还物资  
→ 如有逾期或损坏，记录处罚/赔偿

---

## 五、数据库设计

### 5.1 表总览
建议建立以下 11 张表：

1. `user_account` 用户表
2. `club` 社团表
3. `student` 学生表
4. `venue` 场地表
5. `activity` 活动表
6. `activity_registration` 活动报名表
7. `checkin` 签到表
8. `resource_item` 共享物资表
9. `borrow_order` 借用单表
10. `borrow_detail` 借用明细表
11. `penalty` 处罚表

---

## 六、数据表详细设计

### 6.1 用户表 `user_account`
用途：存储系统登录用户基础信息。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| user_id | BIGINT | PK, AUTO_INCREMENT | 用户主键 |
| username | VARCHAR(50) | UNIQUE, NOT NULL | 登录名 |
| password | VARCHAR(100) | NOT NULL | 密码 |
| role | VARCHAR(20) | NOT NULL | admin / club / student |
| phone | VARCHAR(20) | NULL | 联系电话 |
| create_time | DATETIME | NOT NULL | 创建时间 |

---

### 6.2 社团表 `club`
用途：记录社团信息。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| club_id | BIGINT | PK, AUTO_INCREMENT | 社团主键 |
| club_name | VARCHAR(100) | UNIQUE, NOT NULL | 社团名称 |
| president_user_id | BIGINT | FK | 社长用户 ID |
| contact_phone | VARCHAR(20) | NULL | 联系方式 |
| office_location | VARCHAR(100) | NULL | 办公地点 |

外键：

- `president_user_id -> user_account.user_id`

---

### 6.3 学生表 `student`
用途：记录学生信息。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| student_id | BIGINT | PK, AUTO_INCREMENT | 学生主键 |
| user_id | BIGINT | FK, UNIQUE | 对应用户 |
| student_no | VARCHAR(30) | UNIQUE, NOT NULL | 学号 |
| real_name | VARCHAR(50) | NOT NULL | 真实姓名 |
| grade | VARCHAR(20) | NULL | 年级 |
| major | VARCHAR(50) | NULL | 专业 |
| points | INT | DEFAULT 0 | 活动积分 |
| violation_count | INT | DEFAULT 0 | 违约次数 |

外键：

- `user_id -> user_account.user_id`

---

### 6.4 场地表 `venue`
用途：记录活动场地。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| venue_id | BIGINT | PK, AUTO_INCREMENT | 场地主键 |
| venue_name | VARCHAR(100) | NOT NULL | 场地名称 |
| capacity | INT | NOT NULL | 容纳人数 |
| location | VARCHAR(100) | NULL | 场地位置 |
| status | VARCHAR(20) | DEFAULT 'available' | available / unavailable |

---

### 6.5 活动表 `activity`
用途：系统主业务表。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| activity_id | BIGINT | PK, AUTO_INCREMENT | 活动主键 |
| club_id | BIGINT | FK, NOT NULL | 所属社团 |
| venue_id | BIGINT | FK, NOT NULL | 活动场地 |
| title | VARCHAR(200) | NOT NULL | 活动名称 |
| category | VARCHAR(50) | NULL | 活动类别 |
| start_time | DATETIME | NOT NULL | 开始时间 |
| end_time | DATETIME | NOT NULL | 结束时间 |
| signup_deadline | DATETIME | NOT NULL | 报名截止时间 |
| max_capacity | INT | NOT NULL | 最大人数 |
| status | VARCHAR(20) | NOT NULL | draft / published / ongoing / finished / cancelled |
| description | TEXT | NULL | 活动介绍 |

外键：

- `club_id -> club.club_id`
- `venue_id -> venue.venue_id`

---

### 6.6 活动报名表 `activity_registration`
用途：记录学生报名活动。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| reg_id | BIGINT | PK, AUTO_INCREMENT | 报名主键 |
| activity_id | BIGINT | FK, NOT NULL | 活动 ID |
| student_id | BIGINT | FK, NOT NULL | 学生 ID |
| register_time | DATETIME | NOT NULL | 报名时间 |
| audit_status | VARCHAR(20) | DEFAULT 'approved' | 审核状态 |
| checkin_status | VARCHAR(20) | DEFAULT 'not_checked' | not_checked / checked / absent |

外键：

- `activity_id -> activity.activity_id`
- `student_id -> student.student_id`

额外约束：

- `UNIQUE(activity_id, student_id)`  
  用于防止同一学生重复报名同一活动。

---

### 6.7 签到表 `checkin`
用途：记录签到信息。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| checkin_id | BIGINT | PK, AUTO_INCREMENT | 签到主键 |
| reg_id | BIGINT | FK, NOT NULL | 报名记录 ID |
| checkin_time | DATETIME | NOT NULL | 签到时间 |
| operator_id | BIGINT | FK, NOT NULL | 操作人 |
| status | VARCHAR(20) | NOT NULL | checked / absent |

外键：

- `reg_id -> activity_registration.reg_id`
- `operator_id -> user_account.user_id`

---

### 6.8 共享物资表 `resource_item`
用途：记录可借用物资。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| resource_id | BIGINT | PK, AUTO_INCREMENT | 物资主键 |
| owner_club_id | BIGINT | FK, NOT NULL | 所属社团 |
| item_name | VARCHAR(100) | NOT NULL | 物资名称 |
| category | VARCHAR(50) | NULL | 物资类别 |
| total_qty | INT | NOT NULL | 总数量 |
| available_qty | INT | NOT NULL | 可借数量 |
| unit | VARCHAR(20) | DEFAULT '件' | 单位 |
| deposit_amount | DECIMAL(10,2) | DEFAULT 0 | 押金/赔偿参考金额 |
| status | VARCHAR(20) | DEFAULT 'available' | available / unavailable |

外键：

- `owner_club_id -> club.club_id`

---

### 6.9 借用单表 `borrow_order`
用途：记录某活动的一次借用申请。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| order_id | BIGINT | PK, AUTO_INCREMENT | 借用单主键 |
| activity_id | BIGINT | FK, NOT NULL | 所属活动 |
| applicant_user_id | BIGINT | FK, NOT NULL | 申请人 |
| apply_time | DATETIME | NOT NULL | 申请时间 |
| expected_return_time | DATETIME | NOT NULL | 应归还时间 |
| actual_return_time | DATETIME | NULL | 实际归还时间 |
| order_status | VARCHAR(20) | NOT NULL | pending / approved / borrowed / returned / overdue |

外键：

- `activity_id -> activity.activity_id`
- `applicant_user_id -> user_account.user_id`

---

### 6.10 借用明细表 `borrow_detail`
用途：记录一张借用单中借用的具体物资。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| detail_id | BIGINT | PK, AUTO_INCREMENT | 明细主键 |
| order_id | BIGINT | FK, NOT NULL | 借用单 ID |
| resource_id | BIGINT | FK, NOT NULL | 物资 ID |
| borrow_qty | INT | NOT NULL | 借用数量 |
| returned_qty | INT | DEFAULT 0 | 已归还数量 |
| damage_qty | INT | DEFAULT 0 | 损坏数量 |
| compensation_amount | DECIMAL(10,2) | DEFAULT 0 | 赔偿金额 |

外键：

- `order_id -> borrow_order.order_id`
- `resource_id -> resource_item.resource_id`

---

### 6.11 处罚表 `penalty`
用途：记录未签到、逾期归还、损坏赔偿等处罚信息。

| 字段名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| penalty_id | BIGINT | PK, AUTO_INCREMENT | 处罚主键 |
| student_id | BIGINT | FK, NULL | 学生 ID |
| activity_id | BIGINT | FK, NULL | 活动 ID |
| order_id | BIGINT | FK, NULL | 借用单 ID |
| penalty_type | VARCHAR(30) | NOT NULL | no_show / overdue / damage |
| reason | VARCHAR(200) | NOT NULL | 原因 |
| amount | DECIMAL(10,2) | DEFAULT 0 | 金额 |
| status | VARCHAR(20) | DEFAULT 'unpaid' | unpaid / paid / closed |
| create_time | DATETIME | NOT NULL | 创建时间 |

---

## 七、关键数据库对象设计

### 7.1 事务删除操作

#### 操作目标
删除一个已经取消的活动，同时删除相关的报名记录、签到记录、借用单、借用明细、处罚记录。

#### 为什么使用事务
因为该操作涉及多张关联表。若删除过程中某一步失败，会导致数据不一致，因此必须保证：

- 要么全部删除成功
- 要么全部回滚

#### 涉及表
- `activity`
- `activity_registration`
- `checkin`
- `borrow_order`
- `borrow_detail`
- `penalty`

#### 删除限制
只允许删除状态为 `cancelled` 的活动。

#### 推荐删除顺序
必须先删子表，再删主表：

1. `checkin`
2. `penalty`
3. `borrow_detail`
4. `borrow_order`
5. `activity_registration`
6. `activity`

#### 实现方式（可直接对照 SQL）
- 文件位置：`sql/05_procedure.sql`
- 过程名：`sp_delete_cancelled_activity(p_activity_id)`
- 核心点：
  - 使用事务包裹整段删除逻辑。
  - 先 `SELECT ... FOR UPDATE` 锁住活动记录并校验状态。
  - 状态不是 `cancelled` 直接 `ROLLBACK + SIGNAL`。
  - 严格按“子表 -> 主表”顺序删除，最后 `COMMIT`。

#### 伪代码（答辩可口述）

```text
BEGIN TRANSACTION
  查询并锁定 activity(activity_id)
  IF 活动不存在 OR 状态 != cancelled:
     回滚并报错

  依次删除：checkin -> penalty -> borrow_detail -> borrow_order -> activity_registration -> activity
COMMIT
```

#### 老师可能追问的回答
- 为什么必须事务：中途失败时可回滚，避免部分删除导致数据不一致。
- 为什么用 FOR UPDATE：防止并发下活动状态被其他事务改动。

---

### 7.2 触发器控制添加操作

#### 操作目标
学生报名活动时，向 `activity_registration` 插入记录。

#### 触发器作用
在插入前自动检查以下条件：

1. 活动存在
2. 活动状态必须为 `published`
3. 当前时间不能超过报名截止时间
4. 若活动人数已满，自动进入候补队列
5. 学生不能重复报名

#### 建议触发器名称
`trg_before_insert_registration`

#### 触发器时机
`BEFORE INSERT`

#### 说明
该功能适合作为触发器案例，因为演示效果明显：

- 正常报名成功
- 重复报名失败
- 截止后报名失败
- 人满后进入候补

#### 实现方式（可直接对照 SQL）
- 文件位置：`sql/04_trigger.sql`
- 触发器：`trg_before_insert_registration`
- 核心点：
  - 在 `BEFORE INSERT` 阶段做完整校验。
  - 若已满员，把新报名设为 `reg_status='waiting'`，并分配 `queue_no`。
  - 可选规则：低信用分不可报名热门活动（`category='hot'`）。

#### 伪代码（答辩可口述）

```text
BEFORE INSERT registration:
  查 activity 的状态/截止时间/容量
  IF 不存在 或 非 published 或 超过截止 -> 报错
  IF 已存在同 activity_id + student_id -> 报错

  confirmed_count = 当前已确认人数
  IF confirmed_count < max_capacity:
     NEW.reg_status = confirmed
     NEW.queue_no = NULL
  ELSE:
     NEW.reg_status = waiting
     NEW.queue_no = max(waiting.queue_no) + 1
```

#### 老师可能追问的回答
- 为什么用触发器而不是只写后端：触发器能兜底所有写入入口，保证规则不会被绕过。
- 为什么改成候补而不是失败：业务更实用，也便于演示流程完整性。

---

### 7.3 存储过程控制更新操作

#### 操作目标
活动结束后，统一结算活动相关状态。

#### 建议存储过程名称
`sp_finish_activity`

#### 存储过程功能
输入一个 `activity_id`，完成以下业务：

1. 检查活动是否存在
2. 检查活动状态是否为 `ongoing`
3. 检查当前时间是否晚于 `end_time`
4. 将活动状态改为 `finished`
5. 给签到学生增加积分
6. 给未签到学生增加违约次数
7. 将逾期未归还的借用单状态改为 `overdue`

#### 说明
该操作不是单表更新，而是典型的多表联动更新，非常适合用存储过程实现。

#### 实现方式（可直接对照 SQL）
- 文件位置：`sql/05_procedure.sql`
- 过程名：`sp_finish_activity(p_activity_id)`
- 核心点：
  - 开启事务后先校验活动：存在、`ongoing`、已到结束时间。
  - 更新活动状态为 `finished`。
  - 已签到学生加积分/加信用；未签到学生加违约/扣信用并生成处罚记录。
  - 将逾期借用单标记为 `overdue` 并生成对应处罚。

#### 伪代码（答辩可口述）

```text
BEGIN TRANSACTION
  锁定 activity 行并校验状态与时间
  IF 校验失败 -> 回滚并报错

  更新 activity.status = finished
  更新 student(签到加分，缺席扣信用并加违约)
  插入 no_show 处罚
  更新 borrow_order 为 overdue
  插入 overdue 处罚并扣信用
COMMIT
```

#### 老师可能追问的回答
- 为什么用存储过程：多表联动 + 事务 + 复用，逻辑集中更稳定。
- 如何保证一致性：校验失败统一回滚，成功才提交。

---

### 7.4 视图查询设计

#### 操作目标
查询活动综合统计信息。

#### 建议视图名称
`v_activity_summary`

#### 视图内容
每个活动一行，包含以下信息：

- 活动名称
- 社团名称
- 场地名称
- 活动状态
- 报名人数
- 签到人数
- 借用物资总数

#### 涉及表
- `activity`
- `club`
- `venue`
- `activity_registration`
- `checkin`
- `borrow_order`
- `borrow_detail`

#### 页面用途
统计查询页直接基于该视图展示。

#### 实现方式（可直接对照 SQL）
- 文件位置：`sql/06_view.sql`
- 视图：`v_activity_summary`
- 核心点：
  - 先在子查询中分别预聚合报名统计和借用统计。
  - 再和活动主信息关联，输出“一活动一行”。
  - 同时提供 `v_hot_activity_top10` 用于排行榜展示。

#### 伪代码（答辩可口述）

```text
reg_stats = 按 activity_id 聚合 confirmed/waiting/checked
borrow_stats = 按 activity_id 聚合 borrow_total_qty

v_activity_summary =
  activity
  LEFT JOIN reg_stats
  LEFT JOIN borrow_stats
  JOIN club/venue
```

#### 老师可能追问的回答
- 为什么先预聚合再 join：避免多表直接 join 导致计数重复放大。
- 视图优势：前端只查一个对象，查询接口更稳定。

---

## 八、页面设计

本系统只实现最小可演示页面集，共 6 个页面。

### 8.1 登录页
功能：

- 用户输入用户名和密码
- 根据角色跳转到对应首页

表单字段：

- 用户名
- 密码

按钮：

- 登录

#### 实现方式（后端 + 页面）
- 页面：`templates/login.html`
- 路由：`POST /login`
- 逻辑：校验用户名密码后写入 session，并按角色跳转。

#### 伪代码

```text
提交 username/password
查询 user_account
IF 未找到 -> 返回登录失败
ELSE session 写入 user_id/role
  IF role=admin -> 活动列表页（管理模式）
  IF role=club -> 活动管理页
  IF role=student -> 活动列表页（报名模式）
```

---

### 8.2 活动列表页
功能：

- 显示所有已发布活动
- 支持按名称、状态筛选
- 学生点击进入详情页报名

展示字段：

- 活动名称
- 所属社团
- 场地
- 开始时间
- 报名截止时间
- 状态

按钮：

- 查看详情
- 删除活动（管理员）
- 结算活动（管理员 / 负责人）

#### 实现方式（后端 + 页面）
- 页面：`templates/activity_list.html`
- 路由：`GET /activities`
- 数据来源：主查询 + 可选筛选条件（title/status）
- 管理员按钮分别调用：
  - `POST /activity/delete/<id>`（事务删除）
  - `POST /activity/finish/<id>`（结算存储过程）

#### 伪代码

```text
GET /activities?title=&status=
拼接筛选条件查询 activity + club + venue
返回列表

点击删除:
  调用 sp_delete_cancelled_activity(activity_id)

点击结算:
  调用 sp_finish_activity(activity_id)
```

---

### 8.3 活动详情页
功能：

- 查看活动详细信息
- 学生执行报名

展示字段：

- 活动名称
- 类别
- 描述
- 时间
- 场地
- 最大人数
- 当前报名人数

按钮：

- 报名

#### 实现方式（后端 + 页面）
- 页面：`templates/activity_detail.html`
- 路由：
  - `GET /activity/<id>`：查询详情
  - `POST /activity/register/<id>`：执行报名
- 报名时只做 insert，业务规则交给触发器兜底。

#### 伪代码

```text
GET /activity/{id}
  查询活动详情 + 当前确认人数 + 候补人数

POST /activity/register/{id}
  INSERT INTO activity_registration(activity_id, student_id)
  由 trg_before_insert_registration 自动校验并分配 confirmed/waiting
```

---

### 8.4 活动管理页
功能：

- 社团负责人新增活动
- 修改活动
- 发布活动
- 取消活动

表单字段：

- 活动名称
- 类别
- 场地
- 开始时间
- 结束时间
- 报名截止时间
- 最大人数
- 描述

#### 实现方式（后端 + 页面）
- 页面：`templates/activity_manage.html`
- 路由：
  - `POST /activity/create`
  - `POST /activity/update/<id>`
  - `POST /activity/publish/<id>`
  - `POST /activity/cancel/<id>`
- 发布前建议后端做一次时间合法性校验（与表级 CHECK 双保险）。

#### 伪代码

```text
创建/修改活动:
  接收表单 -> 校验 start/end/deadline
  INSERT 或 UPDATE activity(status=draft)

发布活动:
  检查字段完整性
  UPDATE activity SET status='published'

取消活动:
  UPDATE activity SET status='cancelled'
```

---

### 8.5 物资借用页
功能：

- 为活动创建借用单
- 添加借用明细
- 归还物资

展示字段：

- 借用单编号
- 对应活动
- 物资名称
- 借用数量
- 已归还数量
- 借用状态

按钮：

- 创建借用单
- 添加明细
- 归还物资

#### 实现方式（后端 + 页面）
- 页面：`templates/borrow_manage.html`
- 路由：
  - `POST /borrow/create`
  - `POST /borrow/detail/add`
  - `POST /borrow/return/<order_id>`
- 借用时更新库存；归还时回补库存并更新订单状态。

#### 伪代码

```text
创建借用单:
  INSERT borrow_order(order_status='pending'或'approved')

添加借用明细:
  检查 resource_item.available_qty >= borrow_qty
  INSERT borrow_detail
  UPDATE resource_item.available_qty -= borrow_qty
  UPDATE borrow_order.status='borrowed'

归还:
  更新 borrow_detail.returned_qty / damage_qty
  UPDATE resource_item.available_qty += returned_qty
  若全部归还 -> borrow_order.status='returned', actual_return_time=NOW()
```

---

### 8.6 统计查询页
功能：

- 查询活动综合统计
- 展示视图 `v_activity_summary`

展示字段：

- 活动名称
- 社团
- 场地
- 状态
- 报名人数
- 签到人数
- 借用总数

#### 实现方式（后端 + 页面）
- 页面：`templates/statistics.html`
- 路由：`GET /statistics/activity`
- 直接查询视图 `v_activity_summary`，避免页面端写复杂聚合 SQL。

#### 伪代码

```text
GET /statistics/activity
  SELECT * FROM v_activity_summary ORDER BY activity_id DESC
  渲染统计表格
```

---

## 九、后端接口设计

### 9.1 登录相关

#### `POST /login`
功能：用户登录

参数：

- `username`
- `password`

实现方式：
- 查询 `user_account` 验证凭据。
- 成功后写 session：`user_id`、`role`。
- 失败返回错误提示。

---

### 9.2 活动相关

#### `GET /activities`
功能：活动列表查询

实现方式：
- 查询 `activity + club + venue`。
- 支持 title/status 可选筛选。

#### `GET /activity/<id>`
功能：活动详情查询

实现方式：
- 查询活动主信息。
- 追加报名统计（confirmed/waiting）用于显示当前进度。

#### `POST /activity/create`
功能：创建活动

#### `POST /activity/update/<id>`
功能：修改活动

#### `POST /activity/publish/<id>`
功能：发布活动

#### `POST /activity/cancel/<id>`
功能：取消活动

#### `POST /activity/delete/<id>`
功能：删除活动  
说明：调用事务删除逻辑

实现方式：
- 调用 `CALL sp_delete_cancelled_activity(?)`。
- 捕获 SQL 异常并回传可读错误信息。

#### `POST /activity/finish/<id>`
功能：活动结算  
说明：调用存储过程 `sp_finish_activity`

实现方式：
- 调用 `CALL sp_finish_activity(?)`。
- 成功后返回“结算完成”并刷新统计页。

---

### 9.3 报名相关

#### `POST /activity/register/<id>`
功能：学生报名活动  
说明：插入 `activity_registration`，自动触发报名触发器

实现方式：
- 仅执行 `INSERT activity_registration(activity_id, student_id)`。
- 触发器负责校验、限流和候补分配。

---

### 9.4 签到相关

#### `POST /checkin/<reg_id>`
功能：签到

实现方式：
- `INSERT checkin` 并更新 `activity_registration.checkin_status='checked'`。

#### `POST /absent/<reg_id>`
功能：标记缺席

实现方式：
- 更新 `activity_registration.checkin_status='absent'`。
- 处罚在结算阶段由 `sp_finish_activity` 统一生成。

---

### 9.5 物资相关

#### `GET /resources`
功能：查看物资列表

#### `POST /borrow/create`
功能：创建借用单

实现方式：
- 新增 `borrow_order`，初始状态 `pending/approved`。

#### `POST /borrow/detail/add`
功能：添加借用明细

实现方式：
- 校验库存后新增 `borrow_detail`。
- 同步扣减 `resource_item.available_qty`。

#### `POST /borrow/return/<order_id>`
功能：归还物资

实现方式：
- 更新归还数量/损坏数量。
- 回补库存，必要时更新订单为 `returned`。

---

### 9.6 统计相关

#### `GET /statistics/activity`
功能：活动统计查询  
说明：直接查询视图 `v_activity_summary`

实现方式：
- `SELECT * FROM v_activity_summary`。
- 可扩展支持按状态/时间范围筛选。

---

## 九点五、接口总流程伪代码（用于答辩）

```text
请求进入 Flask 路由
  -> 参数校验
  -> 调用 SQL（普通查询 / 存储过程）
  -> 触发器自动执行业务规则
  -> 事务提交或回滚
  -> 返回 JSON/页面
```

---

## 九点六、写完后怎么看效果（自检与演示）

### A. 数据库对象是否创建成功
按顺序执行：

1. `sql/01_create_database.sql`
2. `sql/02_create_tables.sql`
3. `sql/03_insert_init_data.sql`
4. `sql/04_trigger.sql`
5. `sql/05_procedure.sql`
6. `sql/06_view.sql`
7. `sql/07_event.sql`

检查点：
- `SHOW TRIGGERS;` 能看到报名触发器和审计触发器。
- `SHOW PROCEDURE STATUS WHERE Db='campus_activity_db';` 能看到三个过程。
- `SHOW FULL TABLES WHERE TABLE_TYPE='VIEW';` 能看到两个统计视图。
- `SHOW EVENTS;` 能看到逾期扫描事件。

### B. 功能效果是否正确
建议最少跑 6 个验证场景：

1. 报名成功：插入一条 `activity_registration`（`reg_status=confirmed`）
2. 重复报名失败：同一学生同一活动再次报名被拦截
3. 满员进入候补：新报名 `reg_status=waiting` 且有 `queue_no`
4. 调用结算过程：`CALL sp_finish_activity(activity_id);`
5. 删除取消活动：`CALL sp_delete_cancelled_activity(activity_id);`
6. 查询统计视图：`SELECT * FROM v_activity_summary;`

### C. 页面效果怎么看
启动 Flask 后访问：

1. 登录页：检查角色跳转是否正确
2. 活动列表页：检查筛选、删除、结算按钮
3. 活动详情页：检查报名后状态变化（confirmed/waiting）
4. 统计页：检查视图数据与数据库查询一致

---

## 十、推荐项目目录结构

```text
project/
│
├─ app.py
├─ config.py
├─ requirements.txt
│
├─ models/
│   ├─ __init__.py
│   ├─ user.py
│   ├─ club.py
│   ├─ student.py
│   ├─ venue.py
│   ├─ activity.py
│   ├─ registration.py
│   ├─ checkin.py
│   ├─ resource.py
│   ├─ borrow.py
│   └─ penalty.py
│
├─ routes/
│   ├─ auth_routes.py
│   ├─ activity_routes.py
│   ├─ registration_routes.py
│   ├─ borrow_routes.py
│   └─ statistics_routes.py
│
├─ templates/
│   ├─ login.html
│   ├─ activity_list.html
│   ├─ activity_detail.html
│   ├─ activity_manage.html
│   ├─ borrow_manage.html
│   └─ statistics.html
│
├─ static/
│   ├─ css/
│   └─ js/
│
└─ sql/
    ├─ 01_create_database.sql
    ├─ 02_create_tables.sql
    ├─ 03_insert_init_data.sql
    ├─ 04_trigger.sql
    ├─ 05_procedure.sql
    └─ 06_view.sql

---

## 十一、可加分且实用的增强点（推荐）

以下增强点尽量遵循“开发成本低、演示效果强、数据库特色明显”的原则。

### 11.1 候补队列（Waitlist）

#### 价值
- 报名满员后不直接失败，用户体验更好。
- 活动有人取消后，系统可自动按候补顺序补位，演示效果强。

#### 建议实现
- 在 `activity_registration` 增加字段：
  - `queue_no INT NULL`（候补序号，正式报名为空）
  - `reg_status VARCHAR(20)`（confirmed / waiting / cancelled）
- 报名触发器逻辑扩展：
  - 未满员：`reg_status=confirmed`
  - 满员：`reg_status=waiting` 且自动分配 `queue_no`
- 取消报名后调用存储过程 `sp_promote_waitlist(activity_id)`，将最前候补转正。

### 11.2 活动信用分（学生维度）

#### 价值
- 比单纯积分更“实用”：可用于约束高违约学生报名热门活动。
- 容易写进答辩故事线（制度设计 + 数据规则）。

#### 建议实现
- `student` 表增加：
  - `credit_score INT DEFAULT 100`
- 在 `sp_finish_activity` 中联动更新：
  - 签到：`credit_score +1`（可上限 120）
  - 未签到：`credit_score -5`
  - 逾期归还：`credit_score -8`
- 可增加一个触发器限制：当 `credit_score < 60` 时，不允许报名 `category='热门'` 活动。

### 11.3 自动逾期扫描（MySQL Event）

#### 价值
- 展示“数据库可主动执行任务”，比纯后端定时任务更贴课程特色。

#### 建议实现
- 新建事件 `ev_mark_overdue_orders`，每 30 分钟执行：
  - 将 `expected_return_time < NOW()` 且 `order_status='borrowed'` 的借用单改为 `overdue`。
  - 自动写入一条 `penalty`（`penalty_type='overdue'`）。

### 11.4 审计日志表（操作留痕）

#### 价值
- 非常实用，老师常看重“可追溯性”。
- 触发器案例可再加一个，形成亮点。

#### 建议实现
- 新增 `audit_log` 表：
  - `log_id`, `biz_type`, `biz_id`, `action`, `operator_id`, `old_data`, `new_data`, `op_time`
- 对关键表添加触发器（至少 1 个）：
  - `borrow_order` 状态变更
  - `activity` 状态变更

### 11.5 排行榜视图（有趣且直观）

#### 价值
- 查询结果“好看”，便于演示。
- 直接体现视图和聚合能力。

#### 建议实现
- 新增视图 `v_hot_activity_top10`：
  - 按报名人数、签到率排序，取前 10。
- 新增视图 `v_club_resource_utilization`：
  - 统计社团物资借用总量、逾期率、损坏率。

---

## 十二、数据库完整性与性能补充（建议加入）

### 12.1 CHECK/业务约束（MySQL 8.0）

建议在建表中补充：

- `activity.end_time > activity.start_time`
- `activity.signup_deadline <= activity.start_time`
- `borrow_detail.borrow_qty > 0`
- `borrow_detail.returned_qty >= 0`
- `borrow_detail.damage_qty >= 0`
- `resource_item.available_qty <= resource_item.total_qty`

### 12.2 索引设计（答辩高频点）

建议显式建立以下索引：

- `activity(status, start_time)`：活动列表筛选
- `activity_registration(activity_id, reg_status)`：统计报名/候补
- `checkin(reg_id, status)`：签到统计
- `borrow_order(order_status, expected_return_time)`：逾期扫描
- `borrow_detail(order_id, resource_id)`：借用明细查询
- `penalty(student_id, status)`：学生处罚查询

### 12.3 并发一致性说明

对于“抢报名名额”和“借库存”两类场景，建议在存储过程中使用：

- `SELECT ... FOR UPDATE`
- 明确事务隔离级别（推荐 `READ COMMITTED`）

可在文档补一句：

> 为防止并发下超卖名额或库存，关键扣减操作采用行级锁与事务提交控制。

---

## 十三、可直接开写的 SQL 对象清单

按实现顺序给出最小可交付版本：

1. `01_create_database.sql`
2. `02_create_tables.sql`（含主键、外键、唯一约束、CHECK）
3. `03_insert_init_data.sql`（建议至少 30~50 条可演示数据）
4. `04_trigger.sql`
   - `trg_before_insert_registration`
   - `trg_after_update_borrow_order_audit`（可选加分）
5. `05_procedure.sql`
   - `sp_finish_activity`
   - `sp_delete_cancelled_activity`
   - `sp_promote_waitlist`（可选加分）
6. `06_view.sql`
   - `v_activity_summary`
   - `v_hot_activity_top10`（可选加分）
7. `07_event.sql`（可选加分）
   - `ev_mark_overdue_orders`

---

## 十四、答辩演示脚本（建议）

建议准备 6 段固定演示，确保每段 30~60 秒：

1. 正常报名成功（触发器通过）
2. 重复报名失败（触发器拦截）
3. 满员后进入候补（有趣点）
4. 调用 `sp_finish_activity` 后积分/信用分变化
5. 删除 `cancelled` 活动（事务成功与回滚对比）
6. 查询 `v_activity_summary` 与排行榜视图

---

## 十五、当前计划结论与开写建议

你原计划已经达到“可完成作业”的标准；若想更有亮点，优先加这 3 个：

1. 候补队列（体验提升明显）
2. 审计日志（工程化加分）
3. 热门活动排行榜视图（展示效果好）

这三项实现成本较低，且不会破坏你现有架构，适合马上进入编码阶段。

---

## 十六、关键功能实现方式（伪代码版）

本章用于答辩时解释“功能如何落地”，每个点都给出可口述的实现逻辑。

### 16.1 报名触发器（含候补队列）

#### 功能目标
- 学生报名时自动校验活动状态、截止时间、重复报名。
- 若人数已满，不报错，自动进入候补。

#### 伪代码

```text
BEFORE INSERT activity_registration:
  查询 activity 状态、截止时间、容量、类别
  IF 活动不存在 -> 抛错
  IF 状态 != published -> 抛错
  IF 当前时间 > 报名截止 -> 抛错

  IF 存在同 activity_id + student_id -> 抛错

  查询学生信用分
  IF 活动类别=hot 且 信用分<60 -> 抛错

  confirmed_count = 当前已确认人数
  IF confirmed_count < max_capacity:
     NEW.reg_status = confirmed
     NEW.queue_no = NULL
  ELSE:
     NEW.reg_status = waiting
     NEW.queue_no = 当前最大候补号 + 1
```

#### 可回答点
- 为什么用触发器：保证所有入口（页面/接口/脚本）都统一校验。
- 为什么不只在后端校验：后端可绕过，触发器是数据库最后防线。

### 16.2 候补转正存储过程

#### 功能目标
当已确认报名者取消后，把队首候补转为 confirmed。

#### 伪代码

```text
sp_promote_waitlist(activity_id):
  START TRANSACTION
  找到 queue_no 最小的 waiting 记录（FOR UPDATE）
  IF 不存在候补:
     COMMIT
     RETURN

  将该记录改为 confirmed, queue_no = NULL
  对剩余 waiting 重新从 1 开始编号
  COMMIT
```

#### 可回答点
- 为什么加 FOR UPDATE：防并发下同一候补被重复转正。

### 16.3 活动结算存储过程

#### 功能目标
活动结束后一键结算：改状态、发积分、扣信用、处理逾期。

#### 伪代码

```text
sp_finish_activity(activity_id):
  START TRANSACTION
  锁定活动行并检查：存在、状态=ongoing、当前时间>结束时间
  不满足任一条件 -> ROLLBACK + 抛错

  activity.status = finished

  对已签到学生:
     points += 5
     credit_score = min(120, credit_score + 1)

  对未签到学生:
     violation_count += 1
     credit_score = max(0, credit_score - 5)
     插入 no_show penalty

  将该活动下 overdue 条件满足的借用单改为 overdue
  给对应学生扣信用并插入 overdue penalty

  COMMIT
```

#### 可回答点
- 为什么用存储过程：这是多表联动更新，事务边界在数据库里最稳定。
- 和普通 UPDATE 区别：存储过程可封装流程、参数、异常和事务。

### 16.4 事务删除（取消活动）

#### 功能目标
只删除 cancelled 活动，并级联清理业务数据。

#### 伪代码

```text
sp_delete_cancelled_activity(activity_id):
  START TRANSACTION
  锁定 activity 行
  IF 活动不存在 或 状态 != cancelled:
     ROLLBACK + 抛错

  按依赖顺序删除:
    checkin
    penalty
    borrow_detail
    borrow_order
    activity_registration
    activity

  COMMIT
```

#### 可回答点
- 为什么不能直接删 activity：有外键依赖，直接删会失败或导致脏数据。
- 为什么要先删子表：满足外键约束并保证删除路径清晰。

### 16.5 统计视图

#### 功能目标
给统计页提供“可直接 SELECT”的聚合结果，减少后端拼 SQL。

#### 伪代码

```text
v_activity_summary:
  先按 activity_registration 预聚合得到
    confirmed_count / waiting_count / checked_count
  再按 borrow_order + borrow_detail 预聚合得到 borrow_total_qty
  最后与 activity + club + venue 关联输出一行一个活动

v_hot_activity_top10:
  基于 v_activity_summary
  计算签到率 checked_count / confirmed_count
  按报名人数、签到率排序取前10
```

#### 可回答点
- 为什么先预聚合再 join：避免多表直接 join 时重复放大计数。
- 视图和普通查询差异：视图是可复用查询接口，前后端更稳定。

### 16.6 自动逾期事件

#### 功能目标
数据库每 30 分钟自动扫描逾期借用单并写处罚记录。

#### 伪代码

```text
ev_mark_overdue_orders 每30分钟执行:
  UPDATE borrow_order
  SET order_status = overdue
  WHERE order_status = borrowed
    AND expected_return_time < NOW()

  INSERT overdue penalty
  条件: 该 order 尚无 overdue 类型处罚
```

#### 可回答点
- 为什么用 Event：不依赖应用服务在线，数据库自驱动。
- 线上注意点：需要开启 event_scheduler，且账号有 EVENT 权限。

---

## 十七、老师高频提问与标准回答模板

### 17.1 为什么这个系统数据库设计是合理的？

回答模板：

1. 先按业务拆实体：用户、活动、报名、签到、借用、处罚。
2. 用外键刻画实体关系，保证引用完整性。
3. 用唯一约束和 CHECK 保证关键业务规则不被破坏。
4. 高频查询字段建立复合索引，兼顾正确性和性能。

### 17.2 触发器、存储过程、事务、视图分别解决什么问题？

回答模板：

1. 触发器：解决“写入前规则校验”，防止非法数据入库。
2. 存储过程：解决“多表联动更新”的流程封装和复用。
3. 事务：解决“要么全成要么全回滚”的一致性问题。
4. 视图：解决“复杂查询复用与前端简化”问题。

### 17.3 你如何处理并发问题？

回答模板：

1. 抢名额和库存扣减放在事务中。
2. 对关键记录使用 `SELECT ... FOR UPDATE` 行锁。
3. 失败时抛错并回滚，避免超卖与脏写。

### 17.4 为什么不用只靠后端代码做所有规则？

回答模板：

1. 后端可能有多个入口，不同人写代码容易不一致。
2. 数据库规则是最后防线，能防止绕过后端直接写库。
3. 两层同时做：后端提升提示体验，数据库保证底线正确。

---

## 十八、实现与文档对应关系（便于现场定位）

建议答辩时按以下路径快速展示：

1. 建库脚本：`sql/01_create_database.sql`
2. 建表与索引：`sql/02_create_tables.sql`
3. 初始化数据：`sql/03_insert_init_data.sql`
4. 触发器：`sql/04_trigger.sql`
5. 存储过程：`sql/05_procedure.sql`
6. 视图：`sql/06_view.sql`
7. 定时事件：`sql/07_event.sql`

现场话术建议：

> 文档第十六章讲逻辑，第十八章给脚本定位，我可以从任何一个功能点直接跳到对应 SQL 证明实现。