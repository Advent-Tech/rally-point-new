package service

import (
	"container/list"
	"sync"
	"time"
)

// tileCache is a small TTL + LRU cache for vector tiles with request
// coalescing, so concurrent requests for the same tile hit the DB once.
type tileCache struct {
	mu       sync.Mutex
	maxBytes int
	curBytes int
	ttl      time.Duration
	ll       *list.List
	items    map[string]*list.Element
	inflight map[string]*tileCall
}

type tileEntry struct {
	key     string
	data    []byte
	expires time.Time
}

type tileCall struct {
	wg   sync.WaitGroup
	data []byte
	err  error
}

func newTileCache(maxBytes int, ttl time.Duration) *tileCache {
	return &tileCache{
		maxBytes: maxBytes,
		ttl:      ttl,
		ll:       list.New(),
		items:    make(map[string]*list.Element),
		inflight: make(map[string]*tileCall),
	}
}

// get returns the cached tile or loads it once via load.
func (c *tileCache) get(key string, load func() ([]byte, error)) ([]byte, error) {
	c.mu.Lock()
	if el, ok := c.items[key]; ok {
		e := el.Value.(*tileEntry)
		if time.Now().Before(e.expires) {
			c.ll.MoveToFront(el)
			c.mu.Unlock()
			return e.data, nil
		}
		c.removeLocked(el)
	}
	if call, ok := c.inflight[key]; ok {
		c.mu.Unlock()
		call.wg.Wait()
		return call.data, call.err
	}
	call := &tileCall{}
	call.wg.Add(1)
	c.inflight[key] = call
	c.mu.Unlock()

	call.data, call.err = load()

	c.mu.Lock()
	delete(c.inflight, key)
	if call.err == nil {
		c.addLocked(key, call.data)
	}
	c.mu.Unlock()
	call.wg.Done()
	return call.data, call.err
}

func (c *tileCache) addLocked(key string, data []byte) {
	if len(data) > c.maxBytes {
		return
	}
	el := c.ll.PushFront(&tileEntry{key: key, data: data, expires: time.Now().Add(c.ttl)})
	c.items[key] = el
	c.curBytes += len(data)
	for c.curBytes > c.maxBytes {
		back := c.ll.Back()
		if back == nil {
			break
		}
		c.removeLocked(back)
	}
}

func (c *tileCache) removeLocked(el *list.Element) {
	e := el.Value.(*tileEntry)
	c.ll.Remove(el)
	delete(c.items, e.key)
	c.curBytes -= len(e.data)
}

// clear drops every cached tile (call after territory data changes).
func (c *tileCache) clear() {
	c.mu.Lock()
	c.ll.Init()
	c.items = make(map[string]*list.Element)
	c.curBytes = 0
	c.mu.Unlock()
}
